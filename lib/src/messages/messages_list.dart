import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/models/unreads.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/fusion_connection.dart';
import '../models/messages.dart';
import '../styles.dart';
import 'message_search_results.dart';
import 'sms_conversation_view.dart';

class MessagesTab extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final Softphone _softphone;
  final Function setOnMessagePosted;
  final Function clearOnMessagePosted;

  MessagesTab(this._fusionConnection, this._softphone, this.setOnMessagePosted,
      this.clearOnMessagePosted,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  FusionConnection get _fusionConnection => widget._fusionConnection;
  Function get _setOnMessagePosted => widget.setOnMessagePosted;
  Function get _clearOnMessagePosted => widget.clearOnMessagePosted;

  Softphone? get _softphone => widget._softphone;
  SMSConversation? openConversation = null;
  bool showingResults = false;
  List<SMSConversation> _convos = [];
  List<CrmContact> _crmContacts = [];
  List<Contact> _contacts = [];
  String _myNumber = "";
  bool _loaded = false;
  late StreamSubscription<ConnectivityResult> connectivitySubscription;

  initState() {
    super.initState();
    if (_fusionConnection!.smsDepartments
            .lookupRecord(DepartmentIds.AllMessages) !=
        null) {
      _loaded = true;
    }
    _fusionConnection!.smsDepartments
        .getDepartments((List<SMSDepartment> list) {
      if (!mounted) return;
      this.setState(() {
        _loaded = true;
      });
    });
    connectivitySubscription = _fusionConnection!
        .connectivity.onConnectivityChanged
        .listen(_updateConnectionStatus);
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    setState(() {
      _fusionConnection!.connectivityResult = result;
    });
  }

  @override
  dispose() {
    connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children;
    //if (openConversation == null) {
    children = [
      SearchMessagesView(_fusionConnection, (List<SMSConversation> convos,
          List<CrmContact> crmContacts, List<Contact> contacts) {
        if (!mounted) return;
        this.setState(() {
          showingResults = true;
          _convos = convos;
          _crmContacts = crmContacts;
          _contacts = contacts;
        });
      }, () {
        if (!mounted) return;
        this.setState(() {
          showingResults = false;
        });
      }),
      showingResults
          ? Expanded(
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(16))),
                  padding:
                      EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 0),
                  child: MessageSearchResults(
                      _myNumber,
                      _convos,
                      _contacts,
                      _crmContacts,
                      _fusionConnection,
                      _softphone,
                      null,
                      false)))
          : _loaded
              ? MessagesList(_fusionConnection, _softphone, _setOnMessagePosted,
                  _clearOnMessagePosted)
              : Container()
    ];

    return Container(child: Column(children: children));
  }
}

class MessagesList extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final Softphone? _softphone;
  final Function setOnMessagePosted;
  final Function clearOnMessagePosted;

  MessagesList(this._fusionConnection, this._softphone, this.setOnMessagePosted,
      this.clearOnMessagePosted,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _MessagesListState();
}

class _MessagesListState extends State<MessagesList> {
  FusionConnection get _fusionConnection => widget._fusionConnection;
  Function get _setOnMessagePosted => widget.setOnMessagePosted;
  Function get _clearOnMessagePosted => widget.clearOnMessagePosted;

  Softphone? get _softphone => widget._softphone;
  int lookupState = 0; // 0 - not looking up; 1 - looking up; 2 - got results
  List<SMSConversation> _convos = [];
  String? _selectedGroupId;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then(
      (prefs) {
        setState(() {
          _selectedGroupId =
              prefs.getString('selectedGroupId') ?? DepartmentIds.AllMessages;
          _page = 0;
          _lookupMessages();
        });
      },
    );
    _setOnMessagePosted((dynamic convId) {
      if (mounted) {
        _page = 0;
        _lookupMessages();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _clearOnMessagePosted();
  }

  refreshView(updatedConvoId) {
    setState(() {
      // if(mounted && updatedConvoId != null){
      //   SMSConversation c = _convos.where(
      //     (SMSConversation con) => con.getId() == updatedConvoId).isNotEmpty
      //       ? _convos.where((SMSConversation con) => con.getId() == updatedConvoId).first
      //       : null;
      //   if(c != null){
      //     _convos.remove(c);
      //     _convos.insert(0, c);
      //   }
      // }
    });
  }

  _loadMore() {
    if (_page >= 0 && lookupState != 1) {
      _page += 1;
      _lookupMessages();
    }
  }

  void deleteConvo(SMSConversation conversation, SMSMessage? lastMessage) {
    this.setState(() {
      if (lastMessage != null) {
        _convos.forEach((convo) {
          if (convo.getId() == conversation.getId())
            convo.message!.message = lastMessage.message;
        });
      } else {
        _convos.removeWhere((convo) => convo.getId() == conversation.getId());
      }
    });
  }

  SMSDepartment? _getDepartmentName(SMSConversation convo) {
    if (_selectedGroupId != DepartmentIds.AllMessages)
      return null;
    else {
      return _fusionConnection!.smsDepartments
          .getDepartmentByPhoneNumber(convo.myNumber);
    }
  }

  _lookupMessages({int? limit, int? offset}) {
    if (_selectedGroupId == null) return;
    lookupState = 1;
    _fusionConnection!.conversations.getConversations(
        _selectedGroupId!, limit ?? 100, offset ?? _page * 100,
        (List<SMSConversation> convos, bool fromServer, String departmentId) {
      if (!mounted) return;

      this.setState(() {
        if (fromServer != null && fromServer) {
          lookupState = 2;
        }
        if (fromServer && departmentId != _selectedGroupId) return;
        if (_page == 0) {
          _convos = convos;
        } else {
          Map<String?, SMSConversation> allconvos = {};
          for (SMSConversation s in _convos) allconvos[s.getId()] = s;
          for (SMSConversation s in convos) allconvos[s.getId()] = s;
          _convos = allconvos.values.toList().cast<SMSConversation>();
        }
        _convos.sort((SMSConversation a, SMSConversation b) {
          return DateTime.parse(a.lastContactTime)
                  .isAfter(DateTime.parse(b.lastContactTime))
              ? -1
              : 1;
        });

        if (convos.length < 100 && fromServer) {
          _page = -1;
        }
      });
    });
  }

  // _messagesList() {
  //   return _convos.map((convo) {
  //     return SMSConversationSummaryView(
  //         _fusionConnection, _softphone, convo, _getDepartmentName(convo),_selectedGroupId, deleteConvo);
  //   }).toList();
  // }

  _changeGroup(String newGroupId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedGroupId', newGroupId);
    setState(() {
      _selectedGroupId = newGroupId;
      _page = 0;
    });
    _lookupMessages();
  }

  _selectedDepartmentName() {
    SMSDepartment? dep =
        _fusionConnection!.smsDepartments.getDepartment(_selectedGroupId);

    return dep != null ? dep.groupName : "All Messages";
  }

  List<List<String>> _groupOptions() {
    List<SMSDepartment> departments =
        _fusionConnection.smsDepartments.allDepartments();
    List<List<String>> options = [];

    departments.sort((a, b) => a.groupName == "All Messages"
        ? -1
        : (a.groupName != "All Messages" && int.parse(a.id!) < int.parse(b.id!))
            ? -1
            : 1);
    for (SMSDepartment d in departments) {
      options.add([
        d.groupName ?? "",
        d.id ?? "",
        d.unreadCount.toString(),
        d.id ?? "",
        d.protocol ?? ""
      ]);
    }
    return options;
  }

  _spinner() {
    return Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(bottom: 24, top: 24, left: 48, right: 48),
        child: Center(child: SpinKitThreeBounce(color: smoke, size: 50)));
  }

  _isSpinning() {
    return lookupState < 2 && _convos.length == 0;
  }

  @override
  Widget build(BuildContext context) {
    if (lookupState == 0) {
      _lookupMessages();
    }

    return ValueListenableBuilder<SMSConversation?>(
        valueListenable: _fusionConnection.messages.notification,
        builder: (context, updatedConvo, child) {
          if (updatedConvo != null) {
            _convos.removeWhere((element) =>
                element.conversationId == updatedConvo.conversationId);
            _convos.insert(0, updatedConvo);
            _fusionConnection.messages.viewUpdated();
          }
          return Expanded(
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(16))),
                  padding: EdgeInsets.all(0),
                  //EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 0),
                  child: Stack(children: [
                    Column(children: [
                      Expanded(
                          child: this._isSpinning()
                              ? this._spinner()
                              : ListView.builder(
                                  itemCount: _page == -1
                                      ? _convos.length + 2
                                      : _convos.length + 2,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    if (index == 0) {
                                      return Container(height: 60);
                                    } else if (index - 1 > _convos.length &&
                                        lookupState != 1) {
                                      _loadMore();
                                      return Container(height: 30);
                                    } else if (_convos.length > index - 1) {
                                      return SMSConversationSummaryView(
                                          _fusionConnection,
                                          _softphone,
                                          _convos[index - 1],
                                          _getDepartmentName(
                                              _convos[index - 1]),
                                          _selectedGroupId,
                                          deleteConvo,
                                          refreshView,
                                          _lookupMessages);
                                    } else {
                                      return Container(
                                        child: Text(
                                          _convos.isEmpty
                                              ? 'No conversations'
                                              : '',
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    }
                                  }))
                    ]),
                    Container(
                        height: 80,
                        padding: EdgeInsets.only(
                            top: 16, left: 16, right: 16, bottom: 32),
                        decoration: BoxDecoration(
                            boxShadow: [],
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.5, 1.0],
                                colors: [Colors.white, translucentWhite(0.0)])),
                        margin: EdgeInsets.only(bottom: 24),
                        child: Row(children: [
                          Container(
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width - 70),
                              child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    _selectedDepartmentName().toString(),
                                    style: headerTextStyle,
                                    overflow: TextOverflow.ellipsis,
                                  ))),
                          FusionDropdown(
                              selectedNumber: "",
                              onChange: _changeGroup,
                              value: _selectedGroupId,
                              options: _groupOptions(),
                              label: "Select a Department",
                              button: Container(
                                decoration: BoxDecoration(
                                    color: translucentSmoke,
                                    borderRadius:
                                        BorderRadius.all(Radius.circular(16))),
                                padding: EdgeInsets.only(
                                    top: 10, bottom: 8, right: 9, left: 9),
                                width: 32,
                                height: 32,
                                child: Image.asset(
                                  "assets/icons/down_chevron.png",
                                  width: 12,
                                  height: 6,
                                ),
                              ))
                        ])),
                  ])));
        });
  }
}

class SMSConversationSummaryView extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final Softphone? _softphone;
  final SMSConversation _convo;
  final SMSDepartment? department;
  final String? _selectedGroupId;
  Function(SMSConversation, SMSMessage?)? deleteConvo;
  Function? refreshView;
  Function({int? limit, int? offset})? lookupMessages;

  SMSConversationSummaryView(
      this._fusionConnection,
      this._softphone,
      this._convo,
      this.department,
      this._selectedGroupId,
      this.deleteConvo,
      this.refreshView,
      this.lookupMessages,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _SMSConversationSummaryViewState();
}

class _SMSConversationSummaryViewState
    extends State<SMSConversationSummaryView> {
  FusionConnection get _fusionConnection => widget._fusionConnection;

  Softphone? get _softphone => widget._softphone;

  SMSDepartment? get _department => widget.department;

  SMSConversation get _convo => widget._convo;
  final _searchInputController = TextEditingController();

  String? get _departmentId => widget._selectedGroupId;
  Function(SMSConversation, SMSMessage?)? get _deleteConvo =>
      widget.deleteConvo;
  Function? get _refreshView => widget.refreshView;
  Function({int? limit, int? offset})? get _lookupMessages =>
      widget.lookupMessages;
  SMSConversation? _selectedConvo;

  _openConversation() {
    _fusionConnection.conversations.markRead(_selectedConvo!);
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              SMSConversation displayingConvo = _selectedConvo!;
              return SMSConversationView(
                  fusionConnection: _fusionConnection,
                  softphone: _softphone,
                  smsConversation: displayingConvo,
                  deleteConvo: _deleteConvo,
                  setOnMessagePosted: _refreshView,
                  changeConvo: (SMSConversation convo) {
                    if (mounted) {
                      setState(
                        () {
                          displayingConvo = convo;
                        },
                      );
                    }
                  });
            })).whenComplete(() => _lookupMessages != null
        ? _lookupMessages!(limit: 25, offset: 0)
        : null);
  }

  Widget _departmentTag() {
    Color bg = Color.fromARGB(255, 243, 242, 242);
    Image icon = Image.asset(
      "assets/icons/messages/department.png",
      height: 15,
    );
    Color textColor = char;

    if (_department!.protocol == DepartmentProtocols.FusionChats) {
      bg = fusionChatsBg;
      textColor = fusionChats;
      icon = Image.asset(
        "assets/icons/messages/fusion_chats.png",
        height: 15,
      );
    }

    if (_department!.id == DepartmentIds.Personal) {
      bg = personalChatBg;
      textColor = personalChat;
      icon = Image.asset(
        "assets/icons/messages/personal.png",
        height: 15,
      );
    }

    if (_department!.protocol == DepartmentProtocols.telegram) {
      bg = telegramChatBg;
      textColor = telegramChat;
      icon = Image.asset(
        "assets/icons/messages/telegram.png",
        height: 15,
      );
    }

    if (_department!.protocol == DepartmentProtocols.whatsapp) {
      bg = whatsappChatBg;
      textColor = whatsappChat;
      icon = Image.asset(
        "assets/icons/messages/whatsapp.png",
        height: 15,
      );
    }

    if (_department!.protocol == DepartmentProtocols.facebook) {
      bg = facebookChatBg;
      textColor = facebookChat;
      icon = Image.asset(
        "assets/icons/messages/messenger.png",
        height: 15,
      );
    }

    return Container(
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(2)),
      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          icon,
          Text(
            _department!.groupName!,
            style: TextStyle(
                fontSize: 12, color: textColor, fontWeight: FontWeight.bold),
          )
        ],
      ),
    );
  }

  String makeConvoGroupName() {
    return _convo.filters != null
        ? "Broadcast - Query"
        : _convo.isBroadcast
            ? "Broadcast - Batch"
            : "Group Conversation";
  }

  @override
  Widget build(BuildContext context) {
    String? convoLabel = '';
    DateTime date =
        DateTime.fromMillisecondsSinceEpoch(_convo.message!.unixtime * 1000);
    Coworker? _coworker;

    if (_convo.isGroup) {
      convoLabel =
          _convo.groupName.isNotEmpty ? _convo.groupName : makeConvoGroupName();
    } else {
      if (_convo.number.contains("@")) {
        _fusionConnection.coworkers
            .getRecord(_convo.number, (p0) => _coworker = p0);
      }
      String? contactName = _convo.contactName(coworker: _coworker);
      convoLabel = contactName == "Unknown" && _convo.number != null
          ? _convo.number.formatPhone()
          : contactName;
    }

    return GestureDetector(
        onTap: () {
          setState(() {
            _selectedConvo = _convo;
          });
          _openConversation();
        },
        child: Dismissible(
          key: UniqueKey(),
          direction: DismissDirection.endToStart,
          background: Container(
            color: crimsonDark,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Icon(Icons.delete, color: Colors.white),
              ),
            ),
          ),
          onDismissed: (DismissDirection direction) {
            if (_deleteConvo != null && _departmentId != null) {
              _fusionConnection.conversations
                  .deleteConversation(_convo, _departmentId!);
              _deleteConvo!(_convo, null);
            }
          },
          confirmDismiss: (DismissDirection direction) async {
            return await showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text("Confirm"),
                  content: const Text(
                      "Are you sure you wish to delete this conversation?"),
                  actions: <Widget>[
                    TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: crimsonDark,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text("DELETE")),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text("CANCEL"),
                    ),
                  ],
                );
              },
            );
          },
          child: Container(
              margin: EdgeInsets.only(bottom: 18, left: 16, right: 16),
              child: Row(children: [
                _coworker != null
                    ? ContactCircle.withCoworkerAndDiameter(
                        [], [], _coworker, 60)
                    : ContactCircle.forSMS(_convo.contacts, _convo.crmContacts,
                        _convo.isGroup, _convo.isBroadcast),
                Expanded(
                    child: Container(
                        decoration: BoxDecoration(color: Colors.transparent),
                        child: Row(
                          children: [
                            Expanded(
                                child: Wrap(runSpacing: 4, children: [
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(convoLabel,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16))),
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                      margin: EdgeInsets.only(top: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            Color.fromARGB(255, 243, 242, 242),
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(4)),
                                      ),
                                      padding: EdgeInsets.only(
                                          left: 6, right: 6, top: 2, bottom: 2),
                                      child: Text(
                                          getDateTime(date) +
                                              // (_departmentName != ""
                                              //     ? " " +
                                              //         nDash +
                                              //         " " +
                                              //         _departmentName
                                              //     : "") +
                                              " \u2014 " +
                                              _convo.message!.message!,
                                          style: smallTextStyle,
                                          maxLines: 1,
                                          softWrap: true,
                                          overflow: TextOverflow.ellipsis))),
                              if (_departmentId == DepartmentIds.AllMessages &&
                                  _department != null)
                                _departmentTag()
                            ])),
                            if (_convo.unread! > 0)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 8.0),
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: informationBlue),
                              ),
                            if (_convo.message!.messageStatus == "offline")
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              )
                          ],
                        )))
              ])),
        ));
  }
}

class SearchMessagesView extends StatefulWidget {
  final FusionConnection? _fusionConnection;
  final Function() _onClearSearch;
  final Function(List<SMSConversation>, List<CrmContact>, List<Contact>)
      _onHasResults;

  SearchMessagesView(
      this._fusionConnection, this._onHasResults, this._onClearSearch,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _SearchMessagesViewState();
}

class _SearchMessagesViewState extends State<SearchMessagesView> {
  FusionConnection? get _fusionConnection => widget._fusionConnection;
  final _searchInputController = TextEditingController();

  _openMenu() {
    Scaffold.of(context).openDrawer();
  }

  String groupId = DepartmentIds.Personal;
  String myPhoneNumber = "8014569812";
  String _query = "";
  int willSearch = 0;
  String? _searchingFor;

  Function() get _onClearSearch => widget._onClearSearch;

  Function(List<SMSConversation>, List<CrmContact>, List<Contact>)
      get _onHasResults => widget._onHasResults;

  _search(String val) {
    if (_searchInputController.value.text.trim() == "") {
      this._onClearSearch();
    }
    if (willSearch == 0) {
      willSearch = 1;
      Future.delayed(const Duration(seconds: 1)).then((dynamic x) {
        willSearch = 0;

        String query = _searchInputController.value.text;
        _searchingFor = query;

        _fusionConnection!.messages.searchV2(query,
            (List<SMSConversation> convos, List<CrmContact> crmContacts,
                List<Contact> contacts) {
          if (!mounted) return;
          if (mounted && query == _searchingFor) {
            this._onHasResults(convos, crmContacts, contacts);
          }
        });
      });
    }
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
