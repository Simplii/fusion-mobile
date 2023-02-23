import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';

import '../backend/fusion_connection.dart';
import '../components/fusion_dropdown.dart';
import '../components/sms_header_to_box.dart';
import '../styles.dart';
import '../utils.dart';
import 'message_search_results.dart';
import 'sms_conversation_view.dart';

class NewMessagePopup extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final Softphone _softphone;

  NewMessagePopup(this._fusionConnection, this._softphone, {Key key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _NewMessagePopupState();
}

class _NewMessagePopupState extends State<NewMessagePopup> {
  FusionConnection get _fusionConnection => widget._fusionConnection;
  final _searchTextController = TextEditingController();
  final Debounce _debounce = Debounce(Duration(milliseconds: 700));
  Softphone get _softphone => widget._softphone;
  int willSearch = 0;
  List<SMSConversation> _convos = [];
  List<CrmContact> _crmContacts = [];
  List<Contact> _contacts = [];
  String groupId = "-1";
  String myPhoneNumber = "";
  String _query = "";
  String _searchingFor = "";
  int chipsCount = 0;
  List<dynamic> sendToItems = [];

  initState() {
    super.initState();
    List<String> deptNumbers =
        _fusionConnection.smsDepartments.getDepartment(groupId).numbers;
    if (deptNumbers.length > 0) {
      myPhoneNumber = deptNumbers[0];
    } else {
      myPhoneNumber = "Unassigned";
    }
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    _debounce.dispose();
    super.dispose();
  }

  _search(String value) {
    String query = _searchTextController.value.text;  
    _debounce((){
      if(query.length == 0){
        setState(() {
          _convos = [];
          _crmContacts = [];
          _contacts = [];
        });
      } else if (query != _searchingFor) {
        _searchingFor = query;
        _fusionConnection.contacts.searchV2(query, 50, 0, 
          (List<Contact> contacts, bool fromServer){
            if (mounted && query == _searchingFor) {
              setState(() {
                _contacts = contacts;
                _searchingFor='';
              });
            }
        });
      }
    });
  }

  _deleteChip(int index){
    setState(() {
      chipsCount = chipsCount - 1;
      sendToItems.removeAt(index);
    });
  }

  _addChip(_tappedContact){
    if(_searchTextController.value.text != '' && chipsCount < 10){
      setState(() {
        if(_tappedContact != null){
            chipsCount += 1;
            sendToItems.add(_tappedContact);
        } else if(_searchTextController.value.text.length == 10){
          Contact contact;
          List<Map<String,dynamic>> phoneNumbers;
          for (var c in _contacts) {
            for (var n in c.phoneNumbers) {
              if(n['number'] == _searchTextController.value.text){
                phoneNumbers = [{
                  'number':n['number'],
                  'type':n['type']
                }];
                break;
              }
            }
            contact = c;
          }
          if(contact != null && phoneNumbers !=null){
            contact.phoneNumbers = phoneNumbers;
            chipsCount += 1;
            sendToItems.add(contact);
          } else {
            chipsCount += 1;
            sendToItems.add(_searchTextController.value.text);
          }

        } else {
          chipsCount += 1;
          sendToItems.add(_searchTextController.value.text);
        } 
        _searchTextController.clear();
        _contacts = [];
      });
    } 
  }
  
  _header() {
    String myImageUrl = _fusionConnection.myAvatarUrl();
    List<SMSDepartment> groups = _fusionConnection.smsDepartments
        .getRecords()
        .where((department) => department.id != "-2")
        .toList();

    groups;
    return Column(children: [
      Container(
          alignment: Alignment.center,
          margin: EdgeInsets.only(bottom: 12),
          child: popupHandle()),
      Row(children: [
        Text("FROM: ", style: subHeaderTextStyle),
        Container(
            decoration: dropdownDecoration,
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.only(top: 0, bottom: 0, right: 0, left: 8),
            height: 36,
            child: FusionDropdown(
                selectedNumber: myPhoneNumber,
                departments: _fusionConnection.smsDepartments.allDepartments(),
                onChange: (String value) {
                  this.setState(() {
                    groupId = value;
                    myPhoneNumber = _fusionConnection.smsDepartments
                        .getDepartment(groupId)
                        .numbers[0];
                  });
                },
                onNumberTap: (String value) {
                  this.setState(() {
                    myPhoneNumber = value;
                    groupId = _fusionConnection.smsDepartments
                        .getDepartmentByPhoneNumber(value)
                        .id;
                  });
                },
                label: "Who are you representing?",
                value: groupId,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                options: groups
                    .map((SMSDepartment d) {
                      return [d.groupName, d.id];
                    })
                    .toList()
                    .cast<List<String>>())),
        Spacer(),
      ]),
      SendToBox(
        deleteChip: _deleteChip,
        addChip: _addChip,
        sendToItems: sendToItems,
        search: _search,
        searchTextController: _searchTextController,
        chipsCount: chipsCount,
      )
    ]);
  }

  _startConvo(String query) async {
    List<String> toNumbers = [];
    List<Contact> toContacts = [];

    if(sendToItems.isEmpty && _searchTextController.value.text !=''){
      toNumbers.add(_searchTextController.value.text);
      if(_contacts.length > 0){
        _contacts.forEach((contact) { 
          Contact matchedContactTophone;
          contact.phoneNumbers
          .forEach((phone){
            if( phone['number'] == _searchTextController.value.text){
              matchedContactTophone = contact;
            }
          });
          toContacts.add(matchedContactTophone);
        });
      }
    } else {
      sendToItems.forEach((item) { 
        if(item is String){
          toNumbers.add(item);
          toContacts.add(Contact.fake(item));
        } else {
          toNumbers.add((item as Contact).phoneNumbers[0]['number']);
          toContacts.add(item);
        }
      });
    }
    
    SMSConversation convo = await _fusionConnection.messages.checkExisitingConversation(groupId,
      myPhoneNumber,toNumbers,toContacts);
    
  // print("MyNumber ${convo.serialize()}");
    // SMSConversation convo = SMSConversation.build(
    //   myNumber: myPhoneNumber,
    //   contacts: toContacts,
    //   crmContacts: [],
    //   number: toNumbers.join(','),
    //   isGroup: chipsCount > 1 ?? false,
    //   hash: "${toNumbers.join(':')}"
    // );
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) =>
            SMSConversationView(_fusionConnection, _softphone, convo, null));
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    String query = "" + _searchTextController.value.text;
    query = query.replaceAll(RegExp(r'[^0-9]+'), '');
    bool isPhone = query.length == 10;

    return Container(
        decoration: BoxDecoration(color: Colors.transparent),
        padding: EdgeInsets.only(top: 80, bottom: 0),
        child: Column(children: [
          Container(
              decoration: BoxDecoration(
                  color: particle,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16))),
              padding:
                  EdgeInsets.only(top: 10, left: 14, right: 14, bottom: 12),
              child: _header()),
          Row(children: [
            Expanded(
                child: Container(
                    decoration: BoxDecoration(
                        color: Color.fromARGB(255, 222, 221, 221)),
                    height: 1))
          ]),
          Expanded(
              child: Container(
                  decoration: BoxDecoration(color: Colors.white),
                  // padding: EdgeInsets.only(left: 14, right: 14),
                  child: Column(children: [
                    (isPhone || chipsCount > 0)
                        ? TextButton(
                            onPressed: () {
                              _startConvo(query);
                            },
                            child: Container(
                                alignment: Alignment.center,
                                height: 40,
                                child: Text("Start new conversation \u2794",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: coal,
                                      fontWeight: FontWeight.w400,
                                    ))))
                        : Container(),
                    Expanded(
                        child: Container(
                            child: _convos.length +
                                        _contacts.length +
                                        _crmContacts.length >
                                    0
                                ? MessageSearchResults(
                                    myPhoneNumber,
                                    _convos,
                                    _contacts,
                                    _crmContacts,
                                    _fusionConnection,
                                    _softphone,
                                    _addChip,
                                    true)
                                : Container()))
                  ])))
        ]));
  }
}
