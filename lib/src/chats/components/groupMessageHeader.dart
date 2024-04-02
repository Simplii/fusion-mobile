import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';

class GroupMessageHeader extends StatelessWidget {
  final SMSConversation conversation;
  const GroupMessageHeader({required this.conversation, super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 3),
        child: LimitedBox(
          maxHeight: 50,
          maxWidth: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: conversation.contacts.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              String imageUrl = conversation.contacts[index].pictures.length > 0
                  ? conversation.contacts[index].pictures.last['url']
                  : avatarUrl(conversation.contacts[index].firstName,
                      conversation.contacts[index].lastName);
              ImageProvider image =
                  conversation.contacts[index].profileImage != null
                      ? MemoryImage(conversation.contacts[index].profileImage!)
                      : NetworkImage(imageUrl) as ImageProvider;

              return Align(
                widthFactor: 0.6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Container(
                    height: 50,
                    width: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(60),
                        border: Border.all(color: particle, width: 2),
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: image,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
