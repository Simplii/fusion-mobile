import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/chats/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/chats/components/conversationActions.dart';
import 'package:fusion_mobile_revamped/src/chats/components/conversationDepartmentSelector.dart';
import 'package:fusion_mobile_revamped/src/chats/components/groupMessageHeader.dart';
import 'package:fusion_mobile_revamped/src/chats/components/singleMessageHeader.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/conversation.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class ConversationHeader extends StatefulWidget {
  final SMSConversation conversation;
  final ConversationVM conversationVM;
  final ChatsVM? chatsVM;
  const ConversationHeader({
    required this.conversation,
    required this.conversationVM,
    this.chatsVM,
    super.key,
  });

  @override
  State<ConversationHeader> createState() => _ConversationHeaderState();
}

class _ConversationHeaderState extends State<ConversationHeader> {
  SMSConversation get _conversation => widget.conversation;
  FusionConnection fusionConnection = FusionConnection.instance;
  ConversationVM get _conversationVM => widget.conversationVM;
  ChatsVM? get _chatsVM => widget.chatsVM;
  @override
  Widget build(BuildContext context) {
    Coworker? _coworker =
        _conversation.getCoworker(fusionConnection: fusionConnection);
    return Column(
      children: [
        Center(
          child: Container(
            decoration: BoxDecoration(
              color: halfSmoke,
              borderRadius: BorderRadius.all(
                Radius.circular(3),
              ),
            ),
            width: 36,
            height: 5,
          ),
        ),
        Row(
          children: [
            _conversation.isGroup
                ? GroupMessageHeader(conversation: _conversation)
                : SingleMessageHeader(
                    conversation: _conversation,
                    coworker: _coworker,
                  ),
            ConversationActions(
              conversation: _conversation,
              conversationDepartmentId: _conversation.getDepartmentId(
                fusionConnection: fusionConnection,
              ),
              chatsVM: _chatsVM,
              conversationVM: _conversationVM,
              messages: [], //TODO:add convo messages
            )
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Divider(thickness: 1.5),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DepartmentSelector(
              departments: fusionConnection.smsDepartments.allDepartments(),
              conversation: _conversation,
              conversationVM: _conversationVM,
            )
          ],
        ),
      ],
    );
  }
}
