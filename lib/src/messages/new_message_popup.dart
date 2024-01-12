import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backend/fusion_connection.dart';
import '../components/fusion_dropdown.dart';
import '../components/sms_header_to_box.dart';
import '../styles.dart';
import '../utils.dart';
import 'message_search_results.dart';
import 'sms_conversation_view.dart';

class NewMessagePopup extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final Softphone? _softphone;
  final Function? setOnMessagePosted;
  NewMessagePopup(
      this._fusionConnection, this._softphone, this.setOnMessagePosted,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _NewMessagePopupState();
}

class _NewMessagePopupState extends State<NewMessagePopup> {
  FusionConnection get _fusionConnection => widget._fusionConnection;
  final _searchTextController = TextEditingController();
  final Debounce _debounce = Debounce(Duration(milliseconds: 700));
  Function? get _setOnMessagePosted => widget.setOnMessagePosted;
  Softphone? get _softphone => widget._softphone;
  int willSearch = 0;
  List<SMSConversation> _convos = [];
  List<CrmContact> _crmContacts = [];
  List<Contact> _contacts = [];
  String groupId = DepartmentIds.Personal;
  String myPhoneNumber = "";
  String _query = "";
  String _searchingFor = "";
  int chipsCount = 0;
  List<dynamic> sendToItems = [];

  initState() {
    super.initState();
    SharedPreferences.getInstance().then(
      (prefs) {
        setState(() {
          String _selectedDepartmentId =
              prefs.getString('selectedGroupId') ?? DepartmentIds.Personal;
          groupId = _selectedDepartmentId == DepartmentIds.AllMessages
              ? DepartmentIds.Personal
              : _selectedDepartmentId;
          SMSDepartment dep =
              _fusionConnection!.smsDepartments.getDepartment(groupId);
          List<String> deptNumbers = dep.numbers;
          if (deptNumbers.length > 0) {
            myPhoneNumber = deptNumbers[0];
          } else {
            List<SMSDepartment> deps =
                _fusionConnection!.smsDepartments.allDepartments();
            for (SMSDepartment dep in deps) {
              if (dep.numbers.length > 0 &&
                  dep.id != DepartmentIds.AllMessages &&
                  dep.id != DepartmentIds.FusionChats) {
                myPhoneNumber = dep.numbers[0];
                groupId = dep.id!;
              }
            }
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    _debounce.dispose();
    super.dispose();
  }

  _search(String value) {
    String query = _searchTextController.value.text;
    _debounce(() {
      if (query.length == 0) {
        setState(() {
          _convos = [];
          _crmContacts = [];
          _contacts = [];
        });
      } else if (groupId == DepartmentIds.FusionChats) {
        _fusionConnection!.coworkers.search(query, (p0) {
          setState(() {
            _contacts = [...p0];
            _searchingFor = '';
          });
        });
      } else if (query != _searchingFor) {
        _searchingFor = query;
        bool usesV2 = _fusionConnection!.settings!.isV2User();

        if (!usesV2) {
          _fusionConnection!.contacts.search(query, 50, 0,
              (List<Contact> contacts, bool fromServer, bool fromPhonebook) {
            _fusionConnection!.integratedContacts.search(query, 50, 0,
                (List<Contact> crmContacts, bool fromServer, bool? hasMore) {
              if (mounted && query == _searchingFor) {
                setState(() {
                  _contacts = [...contacts, ...crmContacts];
                  _searchingFor = '';
                });
              }
            });
          });
        } else {
          _fusionConnection!.contacts.searchV2(query, 50, 0, false,
              (List<Contact> contacts, bool fromServer, bool fromPhonebook) {
            if (mounted && query == _searchingFor) {
              setState(() {
                _contacts = contacts;
                _searchingFor = '';
              });
            }
          });
        }
      }
    });
  }

  _deleteChip(int index) {
    setState(() {
      chipsCount = chipsCount - 1;
      sendToItems.removeAt(index);
    });
  }

  _addChip(_tappedContact) {
    if (_searchTextController.value.text != '' && chipsCount < 10) {
      setState(() {
        if (_tappedContact != null) {
          chipsCount += 1;
          sendToItems.add(_tappedContact);
        } else if (_searchTextController.value.text.length == 10) {
          Contact? contact;
          List<Map<String, dynamic>>? phoneNumbers;
          for (var c in _contacts) {
            for (var n in c.phoneNumbers!) {
              if (n['number'] == _searchTextController.value.text) {
                phoneNumbers = [
                  {'number': n['number'], 'type': n['type']}
                ];
                break;
              }
            }
            contact = c;
          }
          if (contact != null && phoneNumbers != null) {
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
    String myImageUrl = _fusionConnection!.myAvatarUrl();
    List<SMSDepartment> groups = _fusionConnection!.smsDepartments
        .allDepartments()
        .where((department) => department.id != DepartmentIds.AllMessages)
        .toList();

    groups.sort(((a, b) => int.parse(a.id!) < int.parse(b.id!) ? -1 : 1));
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
                departments: groups,
                onChange: (String value) {
                  this.setState(() {
                    groupId = value;
                    myPhoneNumber = _fusionConnection!.smsDepartments
                        .getDepartment(groupId)
                        .numbers[0];
                  });
                },
                onNumberTap: (String value) {
                  this.setState(() {
                    myPhoneNumber = value;
                    groupId = _fusionConnection!.smsDepartments
                            .getDepartmentByPhoneNumber(value)!
                            .id ??
                        DepartmentIds.Personal;
                  });
                },
                label: "Departments",
                value: groupId,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                options: groups
                    .map((SMSDepartment d) {
                      return [d.groupName ?? "", d.id ?? ""];
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
        selectedDepartmentId: groupId,
      )
    ]);
  }

  _startConvo(String query) async {
    List<String> toNumbers = [];
    List<Contact> toContacts = [];

    if (sendToItems.isEmpty && _searchTextController.value.text != '') {
      toNumbers.add(_searchTextController.value.text);
      if (_contacts.length > 0) {
        _contacts.forEach((contact) {
          Contact? matchedContactTophone;
          contact.phoneNumbers.forEach((phone) {
            if (phone['number'] == _searchTextController.value.text) {
              matchedContactTophone = contact;
            }
          });
          if (matchedContactTophone != null) {
            toContacts.add(matchedContactTophone!);
          }
        });
      }
    } else {
      sendToItems.forEach((item) {
        if (item is String) {
          toNumbers.add(item);
          toContacts.add(Contact.fake(item));
        } else {
          toNumbers.add((item as Contact).phoneNumbers![0]['number']);
          toContacts.add(item);
        }
      });
    }

    SMSConversation? convo = await _fusionConnection!.messages
        .checkExistingConversation(
            groupId, myPhoneNumber, toNumbers, toContacts);

    Navigator.pop(this.context);
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              SMSConversation? displayingConvo = convo;
              return SMSConversationView(
                  fusionConnection: _fusionConnection,
                  softphone: _softphone,
                  smsConversation: displayingConvo,
                  deleteConvo: null,
                  setOnMessagePosted: _setOnMessagePosted,
                  changeConvo: (SMSConversation updateConvo) {
                    if (!mounted) return;
                    setState(
                      () {
                        displayingConvo = updateConvo;
                      },
                    );
                  });
            }));
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
