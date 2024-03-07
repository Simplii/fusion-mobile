import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/chats/components/messagesList.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/conversation.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class MessagesListView extends StatefulWidget {
  final SMSConversation conversation;
  final ConversationVM conversationVM;
  final ChatsVM? chatsVM;
  final bool isNewConversation;
  const MessagesListView({
    required this.conversation,
    required this.conversationVM,
    this.chatsVM,
    required this.isNewConversation,
    super.key,
  });

  @override
  State<MessagesListView> createState() => _MessagesListViewState();
}

class _MessagesListViewState extends State<MessagesListView> {
  SMSConversation get _conversation => widget.conversation;
  ConversationVM get _conversationVM => widget.conversationVM;
  ChatsVM? get _chatsVM => widget.chatsVM;
  bool get _isNewConversation => widget.isNewConversation;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _conversationVM,
      builder: (BuildContext context, Widget? child) {
        return Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white),
            child: _conversationVM.loadingMessages
                ? Center(
                    child: SpinKitThreeBounce(color: smoke, size: 50),
                  )
                : MessagesList2(
                    messages: _conversationVM.conversationMessages,
                    conversation: _conversation,
                    conversationVM: _conversationVM,
                    isNewConversation: _isNewConversation,
                  ),
          ),
        );
      },
    );
  }
}
