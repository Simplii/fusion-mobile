import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/chats/components/messageRow.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/conversation.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:intl/intl.dart';

class MessagesList2 extends StatefulWidget {
  final List<SMSMessage> messages;
  final SMSConversation conversation;
  final ConversationVM conversationVM;
  final bool isNewConversation;
  const MessagesList2({
    required this.messages,
    required this.conversation,
    required this.conversationVM,
    required this.isNewConversation,
    super.key,
  });

  static DateTime returnDateAndTimeFormat(int time) {
    var dt = DateTime.fromMillisecondsSinceEpoch(time * 1000);
    return DateTime(dt.year, dt.month, dt.day);
  }

  static String groupMessageDateAndTime(int time) {
    var dt = DateTime.fromMillisecondsSinceEpoch(time * 1000);
    final todayDate = DateTime.now();

    final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
    final yesterday =
        DateTime(todayDate.year, todayDate.month, todayDate.day - 1);
    String difference = '';
    final aDate = DateTime(dt.year, dt.month, dt.day);

    if (aDate == today) {
      difference = "Today";
    } else if (aDate == yesterday) {
      difference = "Yesterday";
    } else {
      difference = DateFormat.yMMMd().format(dt).toString();
    }

    return difference;
  }

  @override
  State<MessagesList2> createState() => _MessagesList2State();
}

class _MessagesList2State extends State<MessagesList2> {
  ScrollController _scrollController = ScrollController();
  ConversationVM get _conversationVM => widget.conversationVM;
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreMessages);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreMessages() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        !_conversationVM.loadingMessages) {
      // User has reached the end of the list
      // Load more data or trigger pagination in flutter
      _conversationVM.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isNewConversation && widget.messages.isEmpty) {
      return Container(
        alignment: Alignment.bottomCenter,
        padding: EdgeInsets.only(bottom: 24, top: 24, left: 48, right: 48),
        child: Text(
          "This is the beginning of your text history with ${widget.conversation.contactName() == "Unknown" ? widget.conversation.number : widget.conversation.contactName()}",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: smoke,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: widget.conversationVM.loadingMoreMessages
          ? widget.messages.length + 1
          : widget.messages.length,
      reverse: true,
      itemBuilder: (BuildContext context, int index) {
        if (index == widget.messages.length) {
          return Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: crimsonLight,
                ),
              ),
            ),
          );
        }
        bool isSameDate = false;
        String newDate = '';
        SMSMessage message = widget.messages[index];
        DateTime messageTime = DateTime.fromMillisecondsSinceEpoch(
            widget.messages[index].unixtime * 1000);

        if (index == 0 && widget.messages.length == 1) {
          newDate = MessagesList2.groupMessageDateAndTime(message.unixtime)
              .toString();
        } else if (index == widget.messages.length - 1) {
          newDate = MessagesList2.groupMessageDateAndTime(message.unixtime)
              .toString();
        } else {
          final DateTime date =
              MessagesList2.returnDateAndTimeFormat(message.unixtime);
          final DateTime prevDate = MessagesList2.returnDateAndTimeFormat(
              widget.messages[index + 1].unixtime);
          isSameDate = date.isAtSameMomentAs(prevDate);
          newDate = (isSameDate || widget.messages.length == 1)
              ? ""
              : MessagesList2.groupMessageDateAndTime(message.unixtime)
                  .toString();
        }

        return Column(
          children: [
            if (newDate.isNotEmpty)
              Row(
                children: [
                  horizontalLine(8),
                  Container(
                      margin: EdgeInsets.only(
                          left: 4, right: 4, bottom: 12, top: 12),
                      child: Text(
                        newDate.isNotEmpty
                            ? newDate
                            : DateFormat("E MMM d, y").format(messageTime),
                        style: TextStyle(
                            color: char,
                            fontSize: 12,
                            fontWeight: FontWeight.w700),
                      )),
                  horizontalLine(8)
                ],
              ),
            Dismissible(
              key: ValueKey<SMSMessage>(message),
              direction: DismissDirection.endToStart,
              onDismissed: (DismissDirection direction) {
                widget.conversationVM.deleteMessage(message.id, index);
                if (widget.messages.length == 0) {
                  Navigator.pop(context);
                }
              },
              confirmDismiss: (DismissDirection direction) async {
                return await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text("Confirm"),
                      content: const Text(
                          "Are you sure you wish to delete this message?"),
                      actions: <Widget>[
                        TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: crimsonDark,
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("DELETE")),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text("CANCEL"),
                        ),
                      ],
                    );
                  },
                );
              },
              background: Container(
                color: crimsonDark,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Icon(Icons.delete, color: Colors.white),
                  ),
                ),
              ),
              child: Container(
                margin: EdgeInsets.only(bottom: 18),
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: MessageRow(
                  message: message,
                  conversation: widget.conversation,
                  messageTime: messageTime,
                  conversationVM: _conversationVM,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
