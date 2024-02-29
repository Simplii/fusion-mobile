import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:intl/intl.dart';

class MessagesList2 extends StatelessWidget {
  final List<SMSMessage> messages;
  const MessagesList2({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: messages.length,
      reverse: true,
      itemBuilder: (BuildContext context, int index) {
        return Text(messages[index].message);
      },
    );
  }
}
