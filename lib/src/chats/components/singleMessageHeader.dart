import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';

class SingleMessageHeader extends StatelessWidget {
  final SMSConversation conversation;
  final Coworker? coworker;
  const SingleMessageHeader({
    required this.conversation,
    required this.coworker,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          coworker != null
              ? ContactCircle.withCoworkerAndDiameter([], [], coworker, 60)
              : ContactCircle(conversation.contacts, conversation.crmContacts),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conversation.contactName(coworker: coworker),
                style: headerTextStyle,
              ),
              Text(
                conversation.number.formatPhone(),
                style: subHeaderTextStyle,
              )
            ],
          ),
          Spacer(),
          IconButton(
            icon: Opacity(
                opacity: 0.66,
                child: Image.asset(
                  "assets/icons/phone_dark.png",
                  width: 20,
                  height: 20,
                )),
            onPressed: () {
              Navigator.pop(context);
              // widget.softphone!.makeCall(_conversation!.number);
            },
          ),
        ],
      ),
    );
  }
}
