import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/chats/components/conversationListRow.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class ConversationsSearchResults extends StatelessWidget {
  final ChatsVM chatsVM;
  const ConversationsSearchResults({
    required this.chatsVM,
    super.key,
  });

  // _openConvo(List<Contact> contacts, List<CrmContact> crmContacts) async {
  //   String theirNumber = "";
  //   for (Contact c in contacts) {
  //     for (Map<String, dynamic> phone in c.phoneNumbers) {
  //       if (phone['type'] == "Mobile") {
  //         theirNumber = phone['number'];
  //       }
  //     }
  //   }
  //   for (CrmContact c in crmContacts) {
  //     if (c.phone_number != null) {
  //       theirNumber = c.phone_number!;
  //     }
  //   }

  //   String? myNumber = _fusionConnection!.smsDepartments
  //       .lookupRecord(DepartmentIds.AllMessages)
  //       .numbers[0];

  //   if (myNumber == null) {
  //     showModalBottomSheet(
  //         context: context,
  //         backgroundColor: Colors.transparent,
  //         isScrollControlled: true,
  //         builder: (context) => Container(
  //               constraints: BoxConstraints(
  //                   maxHeight: MediaQuery.of(context).size.height / 2),
  //               child: Center(
  //                 child: Text("No valid texting number found"),
  //               ),
  //             ));
  //   } else if (theirNumber.isEmpty) {
  //     showModalBottomSheet(
  //         context: context,
  //         backgroundColor: Colors.transparent,
  //         isScrollControlled: true,
  //         builder: (context) => Container(
  //               constraints: BoxConstraints(
  //                   maxHeight: MediaQuery.of(context).size.height / 2),
  //               child: Center(
  //                 child: Text("No recepiant valid number found"),
  //               ),
  //             ));
  //   } else {
  //     SMSConversation? convo = await _fusionConnection!.messages
  //         .checkExistingConversation(
  //             DepartmentIds.AllMessages, myNumber, [theirNumber], contacts);

  //     showModalBottomSheet(
  //         context: context,
  //         backgroundColor: Colors.transparent,
  //         isScrollControlled: true,
  //         builder: (context) => StatefulBuilder(
  //                 builder: (BuildContext context, StateSetter setState) {
  //               SMSConversation? displayingConvo = convo;
  //               return SMSConversationView(
  //                   fusionConnection: _fusionConnection,
  //                   softphone: _softphone,
  //                   smsConversation: displayingConvo,
  //                   deleteConvo: null,
  //                   setOnMessagePosted: null,
  //                   changeConvo: (SMSConversation UpdatedConvo) {
  //                     setState(
  //                       () {
  //                         displayingConvo = UpdatedConvo;
  //                       },
  //                     );
  //                   });
  //             }));
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final List<Contact> contacts = chatsVM.conversationsSearchContacts;
    final List<SMSConversation> conversations = chatsVM.foundConversations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: LimitedBox(
            maxHeight: 100,
            child: ListView.builder(
              itemCount: contacts.length,
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                Contact contact = contacts[index];
                return GestureDetector(
                  //TODO: _openConvo
                  onTap: () => print('MDBM object'),
                  child: Container(
                      width: 72,
                      child: Column(children: [
                        ContactCircle.withDiameterAndMargin(
                            [contact], [], 60, 0),
                        Text(contact.firstName ?? "Unknown",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: coal,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        Text(contact.lastName ?? "",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: coal,
                                fontSize: 12,
                                fontWeight: FontWeight.w700))
                      ])),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text("Messages",
              style: TextStyle(
                  color: coal, fontSize: 24, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (context, index) {
              return ConversationRow(
                convo: conversations[index],
                chatsVM: chatsVM,
              );
            },
          ),
        )
      ],
    );
  }
}
