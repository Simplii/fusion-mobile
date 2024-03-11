import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/chats/components/conversationListRow.dart';
import 'package:fusion_mobile_revamped/src/chats/conversationView.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class ConversationsSearchResults extends StatelessWidget {
  final ChatsVM chatsVM;
  final Function resetSearch;
  const ConversationsSearchResults({
    required this.chatsVM,
    required this.resetSearch,
    super.key,
  });

  void _openConversation(SMSConversation convo, BuildContext context) {
    chatsVM.markConversationAsRead(convo);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ConversationView(
          conversation: convo,
          chatsVM: chatsVM,
          isNewConversation: false,
        );
      },
    );
    resetSearch();
  }

  void _startConvo(BuildContext context, Contact contact) async {
    if (contact.phoneNumbers.isEmpty) return;

    SMSConversation convo = await chatsVM.getConversation(
      contact,
      contact.phoneNumbers.first['number'],
      chatsVM.getMyNumber(),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ConversationView(
        conversation: convo,
        chatsVM: chatsVM,
        isNewConversation: true,
      ),
    );
    resetSearch();
  }

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
            child: contacts.isEmpty
                ? Center(
                    child: Text("No contacts found"),
                  )
                : ListView.builder(
                    itemCount: contacts.length,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      Contact contact = contacts[index];
                      return GestureDetector(
                        onTap: () => _startConvo(context, contact),
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
          padding: const EdgeInsets.only(
            bottom: 16,
            left: 16,
          ),
          child: Text("Messages",
              style: TextStyle(
                  color: coal, fontSize: 24, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: conversations.isEmpty
              ? Center(
                  child: Text("No messages found"),
                )
              : ListView.builder(
                  itemCount: conversations.length,
                  padding: EdgeInsets.only(top: 8),
                  itemBuilder: (context, index) {
                    SMSConversation convo = conversations[index];
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openConversation(convo, context),
                      child: ConversationRow(
                        conversation: convo,
                        chatsVM: chatsVM,
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }
}
