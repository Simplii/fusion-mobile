import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/messages/sms_conversation_view.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/models/timeline_items.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../backend/fusion_connection.dart';
import '../styles.dart';
import '../utils.dart';
import 'edit_contact_view.dart';

class ContactProfileView extends StatefulWidget {
  final FusionConnection _fusionConnection;
  Contact _contact;
  final Softphone _softphone;
  final Function refreshUi;

  ContactProfileView(
    this._fusionConnection, 
    this._softphone, 
    this._contact, 
    this.refreshUi, 
    {Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ContactProfileViewState();
}

class _ContactProfileViewState extends State<ContactProfileView> {
  FusionConnection get _fusionConnection => widget._fusionConnection;

  Softphone get _softphone => widget._softphone;

  Contact get _contact => widget._contact;
  TextEditingController _messageInputController = TextEditingController();
  String _selectedTab = 'profile';
  String _selectedPhone = null;
  String _selectedEmail = null;
  List<TimelineItem> _timelineItems = [];
  bool _editing = false;
  int lookupState = 0; // 0 - not looking up; 1 - looking up; 2 - got results
  Function get _refreshUi => widget.refreshUi;
  bool _loading = false;

  _lookupTimeline() {
    if (lookupState == 1) return;
    lookupState = 1;

      // _fusionConnection.timelineItems.getTimelineFromNumbers(
      //     _contact.phoneNumbers
      //         .map((number) => number['number'])
      //         .where((number) => number.length >= 10)
      //         .toList()
      //         .cast<String>(), (List<TimelineItem> items, bool fromServer) {
      //   print("gottimeline");
      //   print(items);
      //   if (!mounted) return;
      //   this.setState(() {
      //     if (fromServer) {
      //       lookupState = 2;
      //     }
      //     _timelineItems = items;
      //   });
      // });

  }

  _headerButton(String tabName, String iconName) {
    return Expanded(
        child: GestureDetector(
            onTap: () {
              this.setState(() {
                _selectedTab = tabName;
              });
            },
            child: Container(
                decoration: BoxDecoration(color: Colors.transparent),
                height: 40,
                margin: EdgeInsets.only(left: 30, right: 30, top: 8),
                child: Column(children: [
                  Expanded(
                      child: Container(
                          margin: EdgeInsets.only(bottom: 12),
                          child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Image.asset(
                                  "assets/icons/" +
                                      iconName +
                                      "_" +
                                      (_selectedTab == tabName
                                          ? 'dark'
                                          : 'light') +
                                      '.png',
                                  width: 20,
                                  height: 20)))),
                  bottomRedBar(_selectedTab != tabName)
                ]))));
  }

  _contactOccupation() {
    bool hasTitle = _contact.jobTitle != null && _contact.jobTitle != "";
    bool hasCompany = _contact.company != null && _contact.company != "";

    if (hasTitle && hasCompany)
      return _contact.jobTitle + " " + mDash + " " + _contact.company;
    else if (hasTitle && !hasCompany)
      return _contact.jobTitle;
    else if (!hasTitle && hasCompany)
      return _contact.company;
    else
      return null;
  }

  _settingsAction(String selectedOption) {
    if (selectedOption == 'edit') {
      setState(() {
        _editing = true;
      });
    } else if (selectedOption.length > 4 &&
        selectedOption.substring(0, 5) == "open:") {
      launch(selectedOption.substring(5));
    }
  }

  _footer() {
    List<Widget> children = [];
    List<ContactCrmReference> crms = _contact.crms();
    crms = crms.sublist(0, min(crms.length, 5));

    for (ContactCrmReference crmRef in crms) {
      children.add(GestureDetector(
          onTap: () {
            launch(crmRef.url);
          },
          child: Container(
              decoration: BoxDecoration(color: Colors.transparent),
              padding: EdgeInsets.only(right: 8),
              child: Image.network(crmRef.icon, width: 24, height: 24))));
    }

    if (_contact.uid != null && _contact.uid != "") {
      Coworker coworker =
          _fusionConnection.coworkers.lookupCoworker(_contact.uid);
      if (coworker != null) {
        children.add(Container(
            margin: EdgeInsets.only(left: 8),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text("Owned by",
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      color: smoke,
                      fontSize: 10,
                      height: 1.4,
                      fontWeight: FontWeight.w800)),
              Text(
                  (coworker.firstName != null ? coworker.firstName : '') +
                      ' ' +
                      (coworker.lastName != null ? coworker.lastName : ''),
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      color: char,
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w700)),
            ])));
      }
    }

    return Container(
        padding: EdgeInsets.all(16), child: Row(children: children));
  }

  _header() {
    String occupation = _contactOccupation();
    String contactStatus = null;
    List<List<String>> settingOptions = [

    ];

    if (new RegExp(r"^[0-9]+$").hasMatch(_contact.id) && 
      _contact.type != ContactType.PrivateContact) {
      settingOptions.add(["Edit", "edit"]);
    }

    List<ContactCrmReference> crms = _contact.crms();

    for (ContactCrmReference ref in crms) {
      settingOptions.add(["Open in " + ref.crmName, "open:" + ref.url]);
    }

    return Column(children: [
      Container(margin: EdgeInsets.all(8), child: Center(child: popupHandle())),
      Stack(children: [
        Row(children: [
          _headerButton("profile", "user"),
          Container(
              margin: EdgeInsets.only(top: 4, bottom: 0),
              child:
                  ContactCircle.withDiameterAndMargin([_contact], [], 74, 0)),
          _headerButton("timeline", "timeline")
        ]),
        if (settingOptions.length > 0)
        Container(
            height: 70,
            alignment: Alignment.centerRight,
            child: FusionDropdown(
                selectedNumber: "",
                onChange: _settingsAction,
                label: _contact.name,
                options: settingOptions,
                button: Container(
                    decoration: BoxDecoration(color: Colors.transparent),
                    padding:
                        EdgeInsets.only(right: 16, left: 16, top: 6, bottom: 4),
                    child: Image.asset("assets/icons/three_dots.png",
                        width: 4, height: 16))))
      ]),
      Container(
          margin: EdgeInsets.only(top: 8, left: 24, right: 24),
          child: Align(
              alignment: Alignment.center,
              child: Text(_contact.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: coal,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)))),
      occupation == null
          ? Container()
          : Container(
              margin: EdgeInsets.only(bottom: 8, left: 24, right: 24),
              child: Align(
                  alignment: Alignment.center,
                  child: Text(occupation,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: coal,
                          fontWeight: FontWeight.w400,
                          fontSize: 12)))),
      contactStatus == null ? Container() : Row(children: [horizontalLine(0)]),
      contactStatus == null
          ? Container(height: 16)
          : Container(
              margin: EdgeInsets.all(8),
              child: Align(
                  alignment: Alignment.center,
                  child: Text(contactStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: coal,
                          fontSize: 12,
                          fontWeight: FontWeight.w400)))),
    ]);
  }

  _getFieldGroups() {
    List<Widget> phones = [];
    List<Widget> emails = [];

    return [
      _renderFieldGroup(
          "phone_filled_dark",
          _contact.phoneNumbers
              .map((number) {
                Map<String, dynamic> phone = number;
                return _renderField(
                    "phone",
                    number['type'] != null && number['type'] != null
                        ? number['type']
                        : 'Phone',
                    number['number'],
                    false);
              })
              .toList()
              .cast<Widget>()),
      if(_contact.emails.isNotEmpty)
        _renderFieldGroup(
          "mail_filled_dark",
          _contact.emails
              .map((email) {
                Map<String, dynamic> mail = email;
                return _renderField(
                    "email",
                    email['type'] != null && email['type'] != null
                        ? email['type']
                        : 'Email',
                    email['email'],
                    false);
              })
              .toList()
              .cast<Widget>()),
    ].cast<Widget>();
  }

  _renderFieldGroup(String iconName, List<Widget> fields) {
    List<Widget> children = fields.toList();
    children.add(Container(
        margin: EdgeInsets.only(left: 12, right: 16),
        child: Row(children: [horizontalLine(20)])));

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
          height: 20,
          width: 20,
          margin: EdgeInsets.only(left: 27, right: 16, top: 12),
          child: Image.asset("assets/icons/" + iconName + ".png",
              height: 20, width: 20)),
      Expanded(child: Column(children: children))
    ]);
  }

  _makeCall(String number) {
    RegExp reg = RegExp(r'[\s()-]');
    Navigator.pop(context);
    _softphone.makeCall(number.replaceAll(reg, ""));
  }

  _openMessage(String theirNumber) async {
    setState(() {
      _loading = true;
    });
    SMSDepartment dept = _fusionConnection.smsDepartments.getDepartment(
      _contact.coworker != null 
      ? DepartmentIds.FusionChats
      : DepartmentIds.Personal
    );
    
    if(dept.numbers.isEmpty){
      _fusionConnection.smsDepartments.getDepartments((List<SMSDepartment> dep) {
        for (SMSDepartment d in dep) {
          if(d.numbers.isNotEmpty){
            dept = d;
            break;
          }
        }
      });
      
      if(dept.numbers.isEmpty){
        return showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => 
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height / 3
              ),
              color: coal,
              child: Center(
                child: Text("No personal/departmens SMS number found for this account", 
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
        ).whenComplete(() =>  setState(() {
          _loading = false;
        }));
      }
    }
   
    SMSConversation convo = await _fusionConnection.messages.checkExistingConversation(
      DepartmentIds.Personal,
      dept.numbers[0],
      [theirNumber],
      [_contact]
    );
    setState(() {
      _loading = false;
    });

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
          builder: (BuildContext context,StateSetter setState) {
            SMSConversation displayingConvo = convo;
          return SMSConversationView(
            fusionConnection: _fusionConnection, 
            softphone: _softphone, 
            smsConversation: displayingConvo, 
            deleteConvo: null,//deletemessage
            setOnMessagePosted: null,//refreshview
            changeConvo: (SMSConversation UpdatedConvo){
              setState(() {
                displayingConvo = UpdatedConvo;
              },);
            }
          );
          },
        ),
      );
  }

  _renderField(String type, String label, String value, bool selected) {
    if (type == "phone") {
      if (_selectedPhone == value)
        return GestureDetector(
            onTap: () {
              this.setState(() {
                _selectedPhone = null;
              });
            },
            child: Container(
                decoration: BoxDecoration(
                    color: particle,
                    borderRadius: BorderRadius.all(Radius.circular(16))),
                margin: EdgeInsets.only(top: 8, bottom: 8, right: 12),
                child: Column(children: [
                  _renderField("text", label, value.formatPhone(), true),
                  Row(children: [horizontalLine(0)]),
                  Container(
                      margin: EdgeInsets.only(
                          top: 12, bottom: 12, right: 12, left: 12),
                      child: Row(children: [
                        actionButton("Call", "phone_dark", 18, 18, () {
                          _makeCall(value);
                        }),
                        actionButton("Message", "message_dark", 18, 18, () {
                          _openMessage(value);
                        },isLoading: _loading)
                      ]))
                ])));
      else
        return GestureDetector(
            onTap: () {
              this.setState(() {
                _selectedPhone = value;
              });
            },
            child: _renderField("text", label, value.formatPhone(), false));
    } else if (type == "text" || type == "email") {
      return Container(
          decoration: BoxDecoration(color: Colors.transparent),
          margin: EdgeInsets.only(top: 10, left: 12, bottom: 10, right: 12),
          child: Column(children: [
            Container(
                margin: EdgeInsets.only(bottom: 4),
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: TextStyle(
                        color: coal,
                        fontSize: 16,
                        fontWeight: FontWeight.w700))),
            Align(
                alignment: Alignment.centerLeft,
                child: Text(label,
                    style: TextStyle(
                        color: selected ? char : smoke,
                        fontSize: 14,
                        fontWeight: FontWeight.w400)))
          ]));
    }
  }

  _spinner() {
    return
      Container(
          alignment: Alignment.center,
          padding: EdgeInsets.only(bottom: 24, top: 24, left: 48, right: 48),
          child: Center(child: SpinKitThreeBounce(color: smoke, size: 50)));
  }

  _noHistoryMessage() {
    return
      Container(
          alignment: Alignment.center,
          padding: EdgeInsets.only(bottom: 24, top: 24, left: 48, right: 48),
          //constraints: BoxConstraints(maxWidth: 170),
          child: this.lookupState < 2
              ? Center(child: SpinKitThreeBounce(color: smoke, size: 50))
              : Text(
                  "This is the beginning of your communications history with " +
                      _contact.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: smoke,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic)));

  }

  _isSpinning() {
    return lookupState < 2 && _timelineItems.length == 0;
  }

  _isEmpty() {
    return lookupState >= 2 && _timelineItems.length == 0;
  }

  List<Widget> _getTimeline() {
    if (_isSpinning())
      return [_spinner()];

    if (_isEmpty())
      return [_noHistoryMessage()];

    List<Widget> list = [];
    DateTime lastDate;
    Widget toAdd;

    for (TimelineItem item in _timelineItems) {
      DateTime thisTime = item.time;

      if (lastDate == null ||
          thisTime.difference(lastDate).inHours.abs() > 24) {
        lastDate = thisTime;

        if (toAdd != null) {
          list.add(toAdd);
        }

        toAdd = Container(
            padding: EdgeInsets.only(left: 16, right: 16),
            child: Row(children: [
              horizontalLine(8),
              Container(
                  margin:
                      EdgeInsets.only(left: 4, right: 4, bottom: 12, top: 12),
                  child: Text(
                    DateFormat("E MMM d, y").format(thisTime),
                    style: TextStyle(
                        color: char, fontSize: 12, fontWeight: FontWeight.w700),
                  )),
              horizontalLine(8)
            ]));
      }

      if (item.type == "message") {
        //TEMP SMSMessageView props NEEDS ATTENTION
        list.add(SMSMessageView(
            _fusionConnection,
            item.message,
            SMSConversation.build(
                myNumber: item.phoneNumber == item.message.to
                    ? item.message.from
                    : item.message.to,
                number: item.phoneNumber,
                contacts: [_contact],
                crmContacts: []),
            (SMSMessage message) {},
            null,
            [],
            DepartmentIds.AllMessages,()=>null));
      } else {
        String duration = Duration(seconds: item.callLog.duration)
            .toString()
            .split('.')
            .first
            .padLeft(8, "0");

        if (item.callLog.duration < 60 * 60) duration = duration.substring(3);
        //TEMP SMSMessageView props NEEDS ATTENTION
        list.add(SMSMessageView(
            _fusionConnection,
            SMSMessage({
              "from": item.callLog.from,
              "to": item.callLog.to,
              "fromMe": item.callLog.type == "Outgoing",
              "id": item.id,
              "isGroup": false,
              "message": (duration +
                  " " +
                  item.callLog.type +
                  " call " +
                  ((item.callLog.disposition == null ||
                          item.callLog.disposition.trim().length == 0)
                      ? ""
                      : (mDash + " " + item.callLog.disposition + " ")) +
                  ((item.callLog.note == null ||
                          item.callLog.note.trim().length == 0)
                      ? ""
                      : (mDash + " " + item.callLog.note))),
              "mime": "",
              "read": true,
              "time": {
                "date": item.time.toString(),
                "timezone": "",
                "timezone_type": 3
              },
              "unixtime": (item.time.millisecondsSinceEpoch / 1000).round(),
              'user': false
            }),
            SMSConversation.build(
                myNumber: item.callLog.type == "Outgoing"
                    ? item.callLog.from
                    : item.callLog.to,
                number: item.callLog.type == "Outgoing"
                    ? item.callLog.to
                    : item.callLog.from,
                contacts: [_contact],
                crmContacts: []),
            (SMSMessage message) {}, 
            null,[],DepartmentIds.AllMessages,()=>null));
      }
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (lookupState == 0) _lookupTimeline();

    List<Widget> children = [];
    Widget bodyContainer;

    if (_editing) {
      bodyContainer = EditContactView(_fusionConnection, _contact, () {
        setState(() {
          this._editing = false;
          if(_refreshUi != null) _refreshUi();
        });
      },null);
    } else {
      bodyContainer = Column(children: [
        _header(),
        Expanded(
            child: Container(
                decoration: whiteForegroundBox(),
                child: ListView(
                    reverse: _selectedTab == 'timeline',
                    padding: EdgeInsets.only(top: 12),
                    children: _selectedTab == "timeline"
                        ? _getTimeline()
                        : _getFieldGroups()))),
        _footer()
      ]);
    }

    return Container(
        child: Column(children: [
      Expanded(
          child: Container(
              decoration: BoxDecoration(color: Colors.transparent),
              padding: EdgeInsets.only(top: 80, bottom: 0),
              child: Container(
                  decoration: BoxDecoration(
                      color: particle,
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16))),
                  child: bodyContainer)))
    ]));
  }
}
