import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/chats/components/messageRow.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:intl/intl.dart';

class MessagesList2 extends StatelessWidget {
  final List<SMSMessage> messages;
  final SMSConversation conversation;
  const MessagesList2({
    required this.messages,
    required this.conversation,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    DateTime tmpDate = DateTime.now().add(Duration(days: 1));
    return ListView.builder(
      itemCount: messages.length,
      reverse: true,
      itemBuilder: (BuildContext context, int index) {
        final SMSMessage message = messages[index];
        final DateTime messageTime =
            DateTime.fromMillisecondsSinceEpoch(message.unixtime * 1000);
        bool isSameDate = false;
        isSameDate = tmpDate.isSameDate(messageTime);
        if (!isSameDate) {
          // Reset tmpDate with current message date
          tmpDate = messageTime;
        }
        return Dismissible(
          key: ValueKey<SMSMessage>(messages[index]),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            // _fusionConnection!.messages
            //     .deleteMessage(this._message.id, _selectedGroupId);
            // _deleteMessage(this._message);
            if (messages.length == 0) {
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
          child: Column(
            children: [
              if (!isSameDate)
                Row(
                  children: [
                    horizontalLine(8),
                    Container(
                        margin: EdgeInsets.only(
                            left: 4, right: 4, bottom: 12, top: 12),
                        child: Text(
                          DateFormat("E MMM d, y").format(messageTime),
                          style: TextStyle(
                              color: char,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        )),
                    horizontalLine(8)
                  ],
                ),
              Container(
                margin: EdgeInsets.only(bottom: 18),
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: MessageRow(
                  message: message,
                  conversation: conversation,
                  messageTime: messageTime,
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
