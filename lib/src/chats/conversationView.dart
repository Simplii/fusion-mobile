import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/chats/components/headerTopRow.dart';
import 'package:fusion_mobile_revamped/src/chats/components/sendMessageInput.dart';
import 'package:fusion_mobile_revamped/src/chats/messagesListView.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/conversation.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class ConversationView extends StatefulWidget {
  final SMSConversation conversation;
  final ChatsVM? chatsVM;
  const ConversationView({
    required this.conversation,
    this.chatsVM,
    super.key,
  });

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  SMSConversation get _conversation => widget.conversation;
  late ConversationVM _conversationVM;
  ChatsVM? get _chatsVM => widget.chatsVM;

  @override
  void initState() {
    _conversationVM = ConversationVM(
      conversation: _conversation,
      chatsVM: _chatsVM,
    );
    super.initState();
  }

  @override
  void dispose() {
    _conversationVM.cancelListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 80),
      child: ListenableBuilder(
        listenable: _conversationVM,
        builder: (BuildContext context, Widget? child) {
          return Container(
            decoration: BoxDecoration(
              color: particle,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                Padding(
                  padding:
                      EdgeInsets.only(top: 10, left: 14, right: 14, bottom: 12),
                  child: ConversationHeader(
                    conversation: _conversationVM.conversation,
                    chatsVM: _chatsVM,
                    conversationVM: _conversationVM,
                  ),
                ),
                Divider(
                  thickness: 1.5,
                  height: 0,
                  indent: 0,
                ),
                MessagesListView(
                  conversation: _conversationVM.conversation,
                  conversationVM: _conversationVM,
                  chatsVM: _chatsVM,
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.fastOutSlowIn,
                  height: _conversationVM.showSnackBar ? 40 : 0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.only(left: 10),
                            color: coal,
                            child: Text(
                              "Sorry you don't have Large MMS turned on",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            )),
                      )
                    ],
                  ),
                ),
                SendMessageInput(
                  conversation: _conversationVM.conversation,
                  conversationVM: _conversationVM,
                  chatsVM: _chatsVM,
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
