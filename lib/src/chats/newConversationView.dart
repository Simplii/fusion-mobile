import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/chats/conversationView.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/newConversationVM.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/components/sms_header_to_box.dart';
import 'package:fusion_mobile_revamped/src/messages/message_search_results.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewMessageView extends StatefulWidget {
  final SharedPreferences sharedPreferences;
  final ChatsVM chatsVM;
  const NewMessageView({
    required this.sharedPreferences,
    required this.chatsVM,
    super.key,
  });

  @override
  State<NewMessageView> createState() => _NewMessageViewState();
}

class _NewMessageViewState extends State<NewMessageView> {
  SharedPreferences get _sharedPreferences => widget.sharedPreferences;
  ChatsVM? get _chatsVM => widget.chatsVM;
  final FusionConnection fusionConnection = FusionConnection.instance;
  final Softphone? softphone = Softphone.instance;
  late final NewConversationVM newConversationVM;

  //UI vars
  final _searchTextController = TextEditingController();
  final Debounce _debounce = Debounce(Duration(milliseconds: 700));
  int chipsCount = 0;
  List<dynamic> sendToItems = [];
  List<SMSConversation> _convos = [];
  List<CrmContact> _crmContacts = [];
  List<Contact> _contacts = [];
  String _searchingFor = "";

  @override
  initState() {
    newConversationVM = NewConversationVM(
      fusionConnection: fusionConnection,
      sharedPreferences: _sharedPreferences,
      softphone: softphone,
    );
    super.initState();
  }

  @override
  dispose() {
    _searchTextController.dispose();
    super.dispose();
  }

  _header() {
    // String myImageUrl = fusionConnection.myAvatarUrl();
    List<SMSDepartment> groups = fusionConnection.smsDepartments
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
                selectedNumber: newConversationVM.getMyNumber(),
                departments: groups,
                onChange: newConversationVM.onDepartmentChange,
                onNumberTap: newConversationVM.onNumberChange,
                label: "Departments",
                value: newConversationVM.selectedDepartmentId ==
                        DepartmentIds.AllMessages
                    ? DepartmentIds.Personal
                    : newConversationVM.selectedDepartmentId,
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
        selectedDepartmentId: newConversationVM.selectedDepartmentId,
      )
    ]);
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
      } else if (newConversationVM.selectedDepartmentId ==
          DepartmentIds.FusionChats) {
        fusionConnection.coworkers.search(query, (p0) {
          setState(() {
            _contacts = [...p0];
            _searchingFor = '';
          });
        });
      } else if (query != _searchingFor) {
        _searchingFor = query;
        bool usesV2 = fusionConnection.settings.isV2User();

        if (!usesV2) {
          fusionConnection!.contacts.search(query, 50, 0,
              (List<Contact> contacts, bool fromServer, bool fromPhonebook) {
            fusionConnection!.integratedContacts.search(query, 50, 0,
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
          fusionConnection.contacts.searchV2(query, 50, 0, false,
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

    SMSConversation? convo =
        await fusionConnection.messages.checkExistingConversation(
      newConversationVM.selectedDepartmentId,
      newConversationVM.getMyNumber(),
      toNumbers,
      toContacts,
    );

    Navigator.pop(this.context);
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => ConversationView(
              conversation: convo,
              chatsVM: _chatsVM,
            ));
  }

  @override
  Widget build(BuildContext context) {
    String query = "" + _searchTextController.value.text;
    query = query.replaceAll(RegExp(r'[^0-9]+'), '');
    bool isPhone = query.length == 10;
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: ListenableBuilder(
          listenable: newConversationVM,
          builder: (BuildContext context, Widget? child) {
            return Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                      color: particle,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      )),
                  padding:
                      EdgeInsets.only(top: 10, left: 14, right: 14, bottom: 12),
                  child: _header(),
                ),
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
                    child: Column(
                      children: [
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
                                    newConversationVM.getMyNumber(),
                                    _convos,
                                    _contacts,
                                    _crmContacts,
                                    fusionConnection,
                                    softphone,
                                    _addChip,
                                    true,
                                  )
                                : Container(),
                          ),
                        )
                      ],
                    ),
                  ),
                )
              ],
            );
          }),
    );
  }
}
