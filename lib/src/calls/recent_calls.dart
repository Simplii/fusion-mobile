import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/components/dialpad_recent_calls.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/contacts/contact_profile_view.dart';
import 'package:fusion_mobile_revamped/src/contacts/edit_contact_view.dart';
import 'package:fusion_mobile_revamped/src/messages/sms_conversation_view.dart';
import 'package:fusion_mobile_revamped/src/models/call_history.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:intl/intl.dart';

import '../backend/fusion_connection.dart';
import '../styles.dart';
import '../utils.dart';

class RecentCallsTab extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final Softphone _softphone;

  RecentCallsTab(this._fusionConnection, this._softphone, {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _RecentCallsTabState();
}

class _RecentCallsTabState extends State<RecentCallsTab> {
  FusionConnection get _fusionConnection => widget._fusionConnection;

  Softphone get _softphone => widget._softphone;
  SMSConversation? openConversation = null;
  bool _showingResults = false;
  String _selectedTab = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    List<Widget> children;
    //if (openConversation == null) {
    children = [
      SearchCallsBar(_fusionConnection, (String query) {
        this.setState(() {
          _query = query;
        });
      }, () {}),
      Container(height: 4),
      Expanded(
          child: RecentCallsList(
              _fusionConnection, _softphone, "Recent Calls", _selectedTab,
              query: _query))
    ];
    return Container(child: Column(children: children));
  }
}

class RecentCallsList extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final Softphone _softphone;
  final String? _label;
  final String _selectedTab;
  final String? query;
  final Function(Contact? contact, CrmContact? crmContact)? onSelect;
  final bool fromDialpad;

  RecentCallsList(
      this._fusionConnection, this._softphone, this._label, this._selectedTab,
      {Key? key, this.onSelect, this.query, this.fromDialpad = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _RecentCallsListState();
}

class _RecentCallsListState extends State<RecentCallsList> {
  FusionConnection get _fusionConnection => widget._fusionConnection;

  Softphone get _softphone => widget._softphone;

  String? get _label => widget._label;

  String get _selectedTab => widget._selectedTab;
  bool get _fromDialpad => widget.fromDialpad;
  int lookupState = 0; // 0 - not looking up; 1 - looking up; 2 - got results
  List<CallHistory> _history = [];
  String? _lookedUpTab;
  String? _subscriptionKey;
  Map<String?, Coworker> _coworkers = {};
  String rand = randomString(10);
  String? expandedId = "";
  int _page = 0;
  int _pageSize = 100;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  expand(item) {
    setState(() {
      if (expandedId == item.id)
        expandedId = "";
      else
        expandedId = item.id;
    });
  }

  initState() {
    super.initState();
    _lookupHistory();
    _softphone.checkMicrophoneAccess(context);
  }

  @override
  dispose() {
    super.dispose();
    if (_subscriptionKey != null) {
      _fusionConnection.coworkers.clearSubscription(_subscriptionKey);
    }
  }

  _loadMore() {
    _page += 1;
    _lookupQuery();
  }

  _lookupQuery() {
    List historyPage = _filteredHistoryItems();
    if (lookupState == 1) return;
    lookupState = 1;

    if (_page == -1) return;
    if (_pageSize > historyPage.length) return;
    _page += 1;
    _lookupHistory();
  }

  _lookupHistory({bool pullToRefresh = false}) async {
    lookupState = 1;
    _lookedUpTab = _selectedTab;

    if (_subscriptionKey != null) {
      _fusionConnection.coworkers.clearSubscription(_subscriptionKey);
    }

    _subscriptionKey =
        _fusionConnection.coworkers.subscribe(null, (List<Coworker> coworkers) {
      if (!mounted) return;
      this.setState(() {
        for (Coworker c in coworkers) {
          _coworkers[c.uid] = c;
        }
      });
    });

    await _fusionConnection.callHistory
        .getRecentHistory(_pageSize, _page * _pageSize, pullToRefresh,
            (List<CallHistory> history, bool fromServer, bool presisted) {
      if (!mounted) return;
      if (!fromServer && _page > 0) return;

      this.setState(() {
        if (fromServer) {
          lookupState = 2;
        }
        Map<String?, CallHistory> oldHistory = new Map<String?, CallHistory>();
        _history.forEach((element) {
          oldHistory[element.cdrIdHash] = element;
        });

        history.forEach((element) {
          if (oldHistory.containsKey(element.cdrIdHash)) return;
          oldHistory[element.cdrIdHash] = element;
        });
        List<CallHistory> list = oldHistory.values.toList();
        list.sort((a, b) {
          return a.startTime!.isBefore(b.startTime!) ? 1 : -1;
        });
        _history = list;
      });
    });
  }

  Future _refreshHistoryList() async {
    return await _lookupHistory(pullToRefresh: true);
  }

  List<CallHistory> _filteredHistoryItems() {
    return _history.where((item) {
      String searchQuery =
          "${item.to}:${item.from}:${item.fromDid}:${item.toDid}:";

      if (item.contact != null)
        searchQuery += item.contact!.searchString() + ":";

      if (item.crmContact != null)
        searchQuery += item.crmContact!.company!.toLowerCase() +
            ":" +
            item.crmContact!.name!.toLowerCase() +
            ":" +
            item.crmContact!.crm!.toLowerCase();

      if (item.coworker != null)
        searchQuery += item.coworker!.firstName!.toLowerCase() +
            ':' +
            item.coworker!.lastName!.toLowerCase();

      if (item.callerId != null && item.callerId!.isNotEmpty) {
        searchQuery += item.callerId!.toLowerCase();
      }

      if (item.callerId != null && item.callerId!.isNotEmpty) {
        searchQuery += item.callerId!.toLowerCase();
      }
      if (widget.query != "" &&
          !searchQuery.contains(widget.query!.toLowerCase())) {
        return false;
      } else if (_selectedTab == 'all') {
        return true;
      } else if (_selectedTab == 'integrated') {
        return item.crmContact != null;
      } else if (_selectedTab == 'coworkers') {
        return item.coworker != null;
      } else if (_selectedTab == 'fusion') {
        return item.contact != null;
      } else {
        return false;
      }
    }).toList();
  }

  _historyList() {
    List<Widget> response = [Container(height: 50)];
    response.addAll(_history.where((item) {
      String searchQuery = item.to! + ":" + item.from! + ":";

      if (item.contact != null)
        searchQuery += item.contact!.searchString() + ":";

      if (item.crmContact != null)
        searchQuery += item.crmContact!.company! +
            ":" +
            item.crmContact!.name! +
            ":" +
            item.crmContact!.crm!;

      if (item.coworker != null)
        searchQuery +=
            item.coworker!.firstName! + ':' + item.coworker!.lastName!;

      if (widget.query != "" && !searchQuery.contains(widget.query!)) {
        return false;
      } else if (_selectedTab == 'all') {
        return true;
      } else if (_selectedTab == 'integrated') {
        return item.crmContact != null;
      } else if (_selectedTab == 'coworkers') {
        return item.coworker != null;
      } else if (_selectedTab == 'fusion') {
        return item.contact != null;
      } else {
        return false;
      }
    }).map((item) {
      if (item.coworker != null && _coworkers[item.coworker!.uid] != null) {
        item.coworker = _coworkers[item.coworker!.uid]!;
      }
      return CallHistorySummaryView(_fusionConnection, _softphone, item,
          onExpand: () {
        expand(item);
      },
          expanded: item.id == expandedId,
          onSelect: widget.onSelect == null
              ? null
              : () {
                  widget.onSelect!(
                      item.coworker != null
                          ? item.coworker!.toContact()
                          : item.contact,
                      item.crmContact);
                });
    }).toList());

    return response;
  }

  Contact _getItemContact(CallHistory item) {
    if (item.coworker != null) {
      return item.coworker!.toContact();
    }
    if (item.contact != null) {
      return item.contact!;
    } else if (item.phoneContact != null) {
      return item.phoneContact!.toContact();
    } else {
      return Contact.fake(item.toDid);
    }
  }

  _historyRow(CallHistory item, int index) {
    if (item.coworker != null && _coworkers[item.coworker!.uid] != null) {
      item.coworker = _coworkers[item.coworker!.uid];
    }
    Widget ret = _fromDialpad
        ? DialpadRecentCalls(
            date: item.startTime,
            contact: _getItemContact(item),
            crmContact: item.crmContact,
            softphone: _softphone,
            onSelect: widget.onSelect)
        : CallHistorySummaryView(_fusionConnection, _softphone, item,
            onExpand: () {
            expand(item);
          },
            expanded: item.id == expandedId,
            refreshHistoryList: _refreshHistoryList,
            onSelect: widget.onSelect == null
                ? null
                : () {
                    widget.onSelect!(
                        item.coworker != null
                            ? item.coworker!.toContact()
                            : item.contact,
                        item.crmContact);
                  });
    if (index == 0 && !_fromDialpad) {
      return Container(padding: EdgeInsets.only(top: 40), child: ret);
    } else {
      return ret;
    }
  }

  _spinner() {
    return Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(bottom: 24, top: 24, left: 48, right: 48),
        child: Center(child: SpinKitThreeBounce(color: smoke, size: 50)));
  }

  _isSpinning() {
    return lookupState < 2 && _history.length == 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_lookedUpTab != _selectedTab) {
      lookupState = 0;
    }
    if (lookupState == 0 && _fusionConnection.isLoginFinished()) {
      _lookupHistory();
    }

    List<CallHistory> historyPage = _filteredHistoryItems();

    return Container(
        child: Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: _fromDialpad
                    ? null
                    : BorderRadius.all(Radius.circular(16))),
            padding: EdgeInsets.only(top: 0, left: 0, right: 0, bottom: 0),
            child: Stack(children: [
              Column(
                children: [
                  Expanded(
                      child: _isSpinning()
                          ? _spinner()
                          : RefreshIndicator(
                              key: _refreshIndicatorKey,
                              triggerMode: RefreshIndicatorTriggerMode.onEdge,
                              onRefresh: () {
                                // For android only users who have Touch vibration turned on in settings will
                                // get the feedback otherwise feedback will be ignored
                                HapticFeedback.mediumImpact();
                                return _refreshHistoryList();
                              },
                              child: historyPage.length == 0
                                  ? Center(
                                      child: Text(_fromDialpad
                                          ? "No Match Was Found"
                                          : "No Recent Calls Found"),
                                    )
                                  : ListView.builder(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      itemCount: _page == -1
                                          ? historyPage.length
                                          : historyPage.length + 1,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        if (index >= historyPage.length) {
                                          _loadMore();
                                          return Container();
                                        } else {
                                          return _historyRow(
                                              historyPage[index], index);
                                        }
                                      }))
                      /*Container(
                              padding: EdgeInsets.only(top: 00),
                              child: RefreshIndicator(
                                onRefresh: () => _refreshHistoryList(),
                                child: CustomScrollView(slivers: [
                                  SliverList(
                                      delegate:
                                      SliverChildListDelegate(_historyList()))
                                ]),
                              )))*/
                      )
                ],
              ),
              if (!_fromDialpad)
                Container(
                    alignment: Alignment.topLeft,
                    decoration: BoxDecoration(
                        boxShadow: [],
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0.5, 1.0],
                            colors: [Colors.white, translucentWhite(0.0)])),
                    height: 60,
                    padding: EdgeInsets.only(
                      bottom: 24,
                      top: 12,
                      left: 16,
                    ),
                    child: Text(_label!.toUpperCase(), style: headerTextStyle)),
            ])));
  }
}

class CallHistorySummaryView extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final CallHistory _historyItem;
  final Softphone _softphone;
  final bool? expanded;
  Function()? onSelect;
  Function()? onExpand;
  Function? refreshHistoryList;

  CallHistorySummaryView(
      this._fusionConnection, this._softphone, this._historyItem,
      {Key? key,
      this.onSelect,
      this.onExpand,
      this.expanded,
      this.refreshHistoryList})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _CallHistorySummaryViewState();
}

class _CallHistorySummaryViewState extends State<CallHistorySummaryView> {
  FusionConnection get _fusionConnection => widget._fusionConnection;

  Softphone get _softphone => widget._softphone;

  CallHistory get _historyItem => widget._historyItem;
  bool? get _expanded => widget.expanded;
  Function? get _refreshHistoryList => widget.refreshHistoryList;
  bool _loading = false;

  initState() {
    super.initState();

    if (_historyItem.coworker == null) {
      var matchingCoworker = _fusionConnection.coworkers.lookupCoworker(
          _historyItem.isInbound() ? _historyItem.from! : _historyItem.to!);
      setState(() {
        _historyItem.coworker = matchingCoworker;
      });
    }
  }

  List<Contact?> _contacts() {
    if (_historyItem.contact != null) {
      return [_historyItem.contact];
    } else if (_historyItem.phoneContact != null) {
      return [_historyItem.phoneContact!.toContact()];
    } else {
      return [];
    }
  }

  List<CrmContact?> _crmContacts() {
    if (_historyItem.crmContact != null) {
      return [_historyItem.crmContact];
    } else {
      return [];
    }
  }

  _expand() {
    if (widget.onExpand != null) {
      widget.onExpand!();
    }
  }

  String _getLinePrefix(String? callerId) {
    String? linePrefix;
    List<dynamic>? domainPrefixes = _fusionConnection.settings.domainPrefixes();
    if (domainPrefixes != null && callerId != null) {
      domainPrefixes.forEach((prefix) {
        if (callerId!.startsWith(prefix)) {
          linePrefix = prefix;
        }
      });
    }
    return linePrefix ?? "";
  }

  _name() {
    if (_historyItem.coworker != null) {
      return _historyItem.coworker!.firstName! +
          ' ' +
          _historyItem.coworker!.lastName!;
    } else if (_historyItem.contact != null) {
      String linePrefix = _getLinePrefix(_historyItem.callerId);
      return linePrefix != ""
          ? linePrefix + "_" + _historyItem.contact!.name!.toTitleCase()
          : _historyItem.contact!.name!.toTitleCase();
    } else if (_historyItem.crmContact != null) {
      return _historyItem.crmContact!.name;
    } else if (_historyItem.phoneContact != null) {
      String linePrefix = _getLinePrefix(_historyItem.callerId);
      return linePrefix != ""
          ? linePrefix + "_" + _historyItem.phoneContact!.name.toTitleCase() 
          : _historyItem.phoneContact!.name.toTitleCase();
    } else if (_historyItem.callerId != null && _historyItem.callerId != '') {
      String linePrefix =  _getLinePrefix(_historyItem.callerId);
      return _historyItem.callerId!.startsWith(linePrefix) && 
             _historyItem.callerId!.replaceAll(linePrefix + "_", "") != "" 
                ? _historyItem.callerId
                : _historyItem.callerId! + "Unknown";
    } else {
      return _historyItem.direction == 'inbound'
          ? _historyItem.fromDid!.formatPhone()
          : _historyItem.toDid!.formatPhone();
    }
  }

  _isMissed() {
    return _historyItem.missed;
  }

  _icon() {
    if (_isMissed()) {
      if (_historyItem.queue == "true") {
        return "assets/icons/queue-call-missed.png";
      } else {
        return "assets/icons/phone_missed_red.png";
      }
    } else if (_historyItem.direction == 'inbound') {
      if (_historyItem.queue == "true") {
        return "assets/icons/queue-call.png";
      } else {
        return "assets/icons/phone_incoming.png";
      }
    } else {
      return "assets/icons/phone_outgoing.png";
    }
  }

  List<Contact> _messageContacts(CallHistory item) {
    List<Contact> contacts = [];
    if (_historyItem.contact != null) {
      contacts.add(_historyItem.contact!);
    } else if (_historyItem.coworker != null) {
      contacts.add(_historyItem.coworker!.toContact());
    } else if (_historyItem.phoneContact != null) {
      contacts.add(_historyItem.phoneContact!.toContact());
    }
    return contacts;
  }

  _openMessage() async {
    bool isExt =
        _historyItem.fromDid!.length < 6 || _historyItem.toDid!.length < 6;
    setState(() {
      _loading = true;
    });
    SMSDepartment dept = _fusionConnection.smsDepartments.getDepartment(
        isExt ? DepartmentIds.FusionChats : DepartmentIds.Personal);
    if (dept.numbers.isEmpty) {
      _fusionConnection.smsDepartments
          .getDepartments((List<SMSDepartment> dep) {
        for (SMSDepartment d in dep) {
          if (d.numbers.isNotEmpty) {
            dept = d;
            break;
          }
        }
      });

      if (dept.numbers.isEmpty) {
        return showModalBottomSheet(
            context: context,
            backgroundColor: coal,
            shape: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            builder: (context) => Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height / 3,
                  ),
                  color: coal,
                  child: Center(
                    child: Text(
                      "No personal/departmens SMS number found for this account",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                )).whenComplete(() => setState(() {
              _loading = false;
            }));
      }
    }
    SMSConversation convo = await _fusionConnection.messages
        .checkExistingConversation(
            DepartmentIds.Personal,
            dept.numbers[0],
            [_historyItem.getOtherNumber(_fusionConnection.getDomain())],
            _messageContacts(_historyItem));

    setState(() {
      _loading = false;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
        SMSConversation displayingConvo = convo;
        return SMSConversationView(
            fusionConnection: _fusionConnection,
            softphone: _softphone,
            smsConversation: displayingConvo,
            deleteConvo: null,
            setOnMessagePosted: null,
            changeConvo: (SMSConversation updateConvo) {
              setState(
                () {
                  displayingConvo = updateConvo;
                },
              );
            });
      }),
    );
  }

  _makeCall() {
    print(
        "MDBM ${_historyItem.to} ${_historyItem.from} ${_historyItem.fromDid}");
    _softphone
        .makeCall(_historyItem.getOtherNumber(_fusionConnection.getDomain()));
  }

  _openProfile() {
    Contact? contact = _historyItem.contact;
    Contact? newContact = null;
    if (contact == null && _historyItem.coworker != null) {
      contact = _historyItem.coworker!.toContact();
    } else if (contact == null && _historyItem.phoneContact != null) {
      contact = _historyItem.phoneContact!.toContact();
    } else if (contact == null &&
        _historyItem.coworker == null &&
        _historyItem.direction == "inbound") {
      newContact = Contact.fake(_historyItem.fromDid);
    } else if (contact == null &&
        _historyItem.coworker == null &&
        _historyItem.direction == "outbound") {
      newContact = Contact.fake(_historyItem.toDid);
    }

    if (contact != null)
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) =>
              ContactProfileView(_fusionConnection, _softphone, contact, () {
                setState(() {
                  _refreshHistoryList!();
                });
              }));
    if (newContact != null) {
      showModalBottomSheet(
          context: context,
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height - 60),
          isScrollControlled: true,
          builder: (context) => EditContactView(_fusionConnection, newContact!,
                  () => Navigator.pop(context, true), () {
                _refreshHistoryList!();
              }));
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [_topPart()];
    bool haveProfile = _historyItem.contact != null ||
            _historyItem.coworker != null ||
            _historyItem.phoneContact != null
        ? true
        : false;
    if (_expanded!) {
      children.add(Container(
          child: Row(children: [horizontalLine(0)]),
          margin: EdgeInsets.only(top: 4, bottom: 4)));
      children.add(Container(
          height: 28,
          margin: EdgeInsets.only(top: 12, bottom: 12),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            actionButton(
                haveProfile ? "" : "", "user_dark", 18, 18, _openProfile,
                flex: 0),
            actionButton("", "phone_dark", 18, 18, _makeCall, flex: 0),
            actionButton("", "message_dark", 18, 18, _openMessage,
                isLoading: _loading, flex: 0)
            // _actionButton("Video", "video_dark", 18, 18, () {}),
          ])));
    }

    return Container(
        height: _expanded! ? 132 : 76,
        padding: EdgeInsets.all(4),
        margin: EdgeInsets.only(bottom: 0, left: 12, right: 12),
        decoration: _expanded!
            ? BoxDecoration(
                color: particle,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ))
            : null,
        child: Column(children: children));
  }

  _relativeDateFormatted(calcDate) {
    final todayAndYesterdayFmt = new DateFormat("h:mm a");
    final olderThanYesterdayFmt = new DateFormat("M/d h:mm a");
    final today = DateTime.now();
    final lastMidnight = new DateTime(today.year, today.month, today.day);

    if (lastMidnight.isBefore(calcDate)) {
      return "Today " + todayAndYesterdayFmt.format(calcDate);
    } else if (lastMidnight
        .subtract(new Duration(days: 1))
        .isBefore(calcDate)) {
      return "Yesterday " + todayAndYesterdayFmt.format(calcDate);
    } else {
      return olderThanYesterdayFmt.format(calcDate);
    }
  }

  _topPart() {
    return GestureDetector(
        onTap: () {
          if (widget.onSelect != null)
            widget.onSelect!();
          else
            _expand();
        },
        child: Row(children: [
          ContactCircle.withCoworker(
              _contacts(), _crmContacts(), _historyItem.coworker),
          Expanded(
              child: Container(
                  decoration: BoxDecoration(color: Colors.transparent),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(_name() != null ? _name() : "Unknown",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Row(children: [
                              Container(
                                  margin: EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: _expanded!
                                        ? Colors.white
                                        : Color.fromARGB(255, 243, 242, 242),
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(4)),
                                  ),
                                  alignment: Alignment.topLeft,
                                  padding: EdgeInsets.only(
                                      left: 6, right: 6, top: 2, bottom: 2),
                                  child: Row(children: [
                                    Image.asset(_icon(), width: 12, height: 12),
                                    Container(width: 2),
                                    Text(
                                        " " +
                                            ("" +
                                                    _historyItem.getOtherNumber(
                                                        _fusionConnection
                                                            .getDomain()))
                                                .toString()
                                                .formatPhone() +
                                            " " +
                                            mDash +
                                            " " +
                                            _relativeDateFormatted(
                                                _historyItem.startTime),
                                        style: TextStyle(
                                            color: _isMissed()
                                                ? crimsonDarker
                                                : coal,
                                            fontSize: 12,
                                            height: 1.4,
                                            fontWeight: FontWeight.w400))
                                  ])),
                              Expanded(child: Container())
                            ]))
                      ])))
        ]));
  }
}

class SearchCallsBar extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final Function() _onClearSearch;
  final Function(String query) _onChange;

  SearchCallsBar(this._fusionConnection, this._onChange, this._onClearSearch,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _SearchCallsBarState();
}

class _SearchCallsBarState extends State<SearchCallsBar> {
  final _searchInputController = TextEditingController();
  String? _selectedTab_selectedTab;

  _openMenu() {
    Scaffold.of(context).openDrawer();
  }

  String _query = "";
  int willSearch = 0;

  Function() get _onClearSearch => widget._onClearSearch;

  Function(String query) get _onChange => widget._onChange;

  _search(String val) {
    Future.delayed(const Duration(seconds: 1)).then((dynamic x) {
      String query = _searchInputController.value.text.trim();
      _onChange(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 8),
        child: Container(
            padding: EdgeInsets.only(left: 4, right: 16, top: 8, bottom: 8),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                color: Color.fromARGB(85, 0, 0, 0)),
            child: Row(children: [
              Container(
                height: 24,
                width: 36,
                margin: EdgeInsets.all(0),
                child: IconButton(
                  padding: EdgeInsets.all(0),
                  icon: Image.asset("assets/icons/hamburger.png",
                      height: 30, width: 45),
                  //constraints: BoxConstraints(maxHeight: 12, maxWidth: 18),
                  onPressed: _openMenu,
                ),
              ),
              Expanded(
                  child: Container(
                      margin: EdgeInsets.only(left: 12),
                      height: 38,
                      child: TextField(
                          onChanged: _search,
                          style: TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                  color: Color.fromARGB(255, 154, 148, 149)),
                              hintText: "Search"),
                          controller: _searchInputController)))
            ])));
  }
}
