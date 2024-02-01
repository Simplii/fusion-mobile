import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';

import '../backend/fusion_connection.dart';
import '../components/sms_header_to_box.dart';
import '../styles.dart';
import 'messages_list.dart';
import 'sms_conversation_view.dart';

class MessageSearchResults extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final List<SMSConversation> _conversations;
  final List<Contact> _contacts;
  final List<CrmContact> _crmContacts;
  final String? _myNumber;
  final Softphone? _softphone;
  final Function(dynamic)? addChip;
  final bool showContactList;
  MessageSearchResults(
      this._myNumber,
      this._conversations,
      this._contacts,
      this._crmContacts,
      this._fusionConnection,
      this._softphone,
      this.addChip,
      this.showContactList,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _MessageSearchResults();
}

class _MessageSearchResults extends State<MessageSearchResults> {
  FusionConnection get _fusionConnection => widget._fusionConnection;
  Softphone? get _softphone => widget._softphone;

  List<SMSConversation> get _conversations => widget._conversations;

  List<Contact> get _contacts => widget._contacts;

  List<CrmContact> get _crmContacts => widget._crmContacts;
  Function(dynamic)? get _addChip => widget.addChip;
  bool get _showContactsList => widget.showContactList;

  _openConvo(List<Contact> contacts, List<CrmContact> crmContacts) async {
    String theirNumber = "";
    for (Contact c in contacts) {
      for (Map<String, dynamic> phone in c.phoneNumbers) {
        if (phone['type'] == "Mobile") {
          theirNumber = phone['number'];
        }
      }
    }
    for (CrmContact c in crmContacts) {
      if (c.phone_number != null) {
        theirNumber = c.phone_number!;
      }
    }

    String? myNumber = _fusionConnection!.smsDepartments
        .lookupRecord(DepartmentIds.AllMessages)
        .numbers[0];

    if (myNumber == null) {
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height / 2),
                child: Center(
                  child: Text("No valid texting number found"),
                ),
              ));
    } else if (theirNumber.isEmpty) {
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height / 2),
                child: Center(
                  child: Text("No recepiant valid number found"),
                ),
              ));
    } else {
      SMSConversation? convo = await _fusionConnection!.messages
          .checkExistingConversation(
              DepartmentIds.AllMessages, myNumber, [theirNumber], contacts);

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
                    setOnMessagePosted: null,
                    changeConvo: (SMSConversation UpdatedConvo) {
                      setState(
                        () {
                          displayingConvo = UpdatedConvo;
                        },
                      );
                    });
              }));
    }
  }

  _contactBubbles() {
    List<Widget> bubbles = [];
    for (Contact c in _contacts) {
      bubbles.add(GestureDetector(
          onTap: () {
            _openConvo([c], []);
          },
          child: Container(
              margin: EdgeInsets.only(top: 10),
              width: 72,
              child: Column(children: [
                ContactCircle.withDiameterAndMargin([c], [], 60, 0),
                Align(
                    alignment: Alignment.center,
                    child: Text(c.firstName!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: coal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
                Align(
                    alignment: Alignment.center,
                    child: Text(c.lastName!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: coal,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)))
              ]))));
    }
    for (CrmContact c in _crmContacts) {
      bubbles.add(GestureDetector(
          onTap: () {
            _openConvo([], [c]);
          },
          child: Container(
              width: 72,
              margin: EdgeInsets.only(top: 12),
              child: Column(children: [
                ContactCircle.withDiameterAndMargin([], [c], 60, 0),
                Text(c.name!.split(r' ')[0],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: coal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                Text(c.name!.split(r' ').sublist(1).join(' '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: coal, fontSize: 12, fontWeight: FontWeight.w700))
              ]))));
    }
    return bubbles;
  }

  _messagesList() {
    return _conversations.map((SMSConversation convo) {
      return SMSConversationSummaryView(
          _fusionConnection, _softphone, convo, null, "", null, null, null);
    }).toList();
  }

  Widget SearchInConversationView() {
    return Column(children: [
      Container(
          height: 100,
          child: ListView(
              children: _contactBubbles(), scrollDirection: Axis.horizontal)),
      Container(
          padding: EdgeInsets.only(top: 14, bottom: 14),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Messages",
                  style: TextStyle(
                      color: coal,
                      fontSize: 24,
                      fontWeight: FontWeight.w700)))),
      Expanded(child: ListView(children: _messagesList()))
    ]);
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> newContactsList = [];
    _contacts.forEach((element) {
      if (element.phoneNumbers.length > 1) {
        element.phoneNumbers.forEach((number) {
          newContactsList.add({
            'contact': element,
            'phone': number['number'],
            'type': number['type']
          });
        });
      } else if (element.phoneNumbers.length == 1) {
        newContactsList.add(
            {'contact': element, 'phone': element.phoneNumbers[0]['number']});
      }
    });

    return _showContactsList
        ? Scaffold(
            extendBody: true,
            resizeToAvoidBottomInset: true,
            body: Container(
              height: MediaQuery.of(context).size.height,
              child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: newContactsList.length,
                  separatorBuilder: (context, index) => Divider(
                        color: halfSmoke,
                      ),
                  itemBuilder: (BuildContext context, int index) {
                    return Container(
                      margin: EdgeInsets.only(top: index == 0 ? 8 : 0),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          if (_addChip != null) {
                            Contact c = newContactsList[index]['contact'];
                            c.phoneNumbers = [
                              {
                                'number':
                                    newContactsList[index]['phone'].toString(),
                                'type': newContactsList[index]['type']
                              }
                            ];
                            _addChip!(c);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ContactCircle.withDiameterAndMargin(
                                  [newContactsList[index]['contact']],
                                  [],
                                  60,
                                  0),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  newContactsList[index]['contact']
                                      .name
                                      .toString()
                                      .toTitleCase(),
                                  style: TextStyle(
                                      color: coal,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    newContactsList[index]['phone']
                                        .toString()
                                        .formatPhone(),
                                    style: TextStyle(
                                        color: char,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                )
                              ],
                            ),
                          ]),
                        ),
                      ),
                    );
                  }),
            ),
          )
        : SearchInConversationView();
  }
}
