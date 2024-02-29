import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/chats/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';

class ConversationRow extends StatelessWidget {
  final SMSConversation convo;
  final ChatsVM chatsVM;
  const ConversationRow({
    required this.convo,
    required this.chatsVM,
    super.key,
  });

  String _makeConvoGroupName() {
    return convo.filters != null
        ? "Broadcast - Query"
        : convo.isBroadcast
            ? "Broadcast - Batch"
            : "Group Conversation";
  }

  Widget _departmentTag() {
    Color bg = Color.fromARGB(255, 243, 242, 242);
    Image icon = Image.asset(
      "assets/icons/messages/department.png",
      height: 15,
    );
    Color textColor = char;
    final SMSDepartment _department = chatsVM.getConversationDepartment(
      convoMyNumber: convo.myNumber,
    );
    if (_department.protocol == DepartmentProtocols.FusionChats) {
      bg = fusionChatsBg;
      textColor = fusionChats;
      icon = Image.asset(
        "assets/icons/messages/fusion_chats.png",
        height: 15,
      );
    }

    if (_department.id == DepartmentIds.Personal) {
      bg = personalChatBg;
      textColor = personalChat;
      icon = Image.asset(
        "assets/icons/messages/personal.png",
        height: 15,
      );
    }

    if (_department.protocol == DepartmentProtocols.telegram) {
      bg = telegramChatBg;
      textColor = telegramChat;
      icon = Image.asset(
        "assets/icons/messages/telegram.png",
        height: 15,
      );
    }

    if (_department.protocol == DepartmentProtocols.whatsapp) {
      bg = whatsappChatBg;
      textColor = whatsappChat;
      icon = Image.asset(
        "assets/icons/messages/whatsapp.png",
        height: 15,
      );
    }

    if (_department.protocol == DepartmentProtocols.facebook) {
      bg = facebookChatBg;
      textColor = facebookChat;
      icon = Image.asset(
        "assets/icons/messages/messenger.png",
        height: 15,
      );
    }

    return Container(
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(2)),
      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          icon,
          Text(
            _department.groupName ?? "Unknown Department Name",
            style: TextStyle(
                fontSize: 12, color: textColor, fontWeight: FontWeight.bold),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String convoLabel = '';
    Coworker? _coworker;
    DateTime date =
        DateTime.fromMillisecondsSinceEpoch(convo.message!.unixtime * 1000);
    if (convo.isGroup) {
      convoLabel =
          convo.groupName.isNotEmpty ? convo.groupName : _makeConvoGroupName();
    } else {
      // if (convo.number.contains("@")) {
      //   _fusionConnection.coworkers
      //       .getRecord(convo.number, (p0) => _coworker = p0);
      // }
      String? contactName = convo.contactName(coworker: _coworker);
      convoLabel = contactName == "Unknown" && convo.number.isNotEmpty
          ? convo.number.formatPhone()
          : contactName;
    }
    return Container(
        margin: EdgeInsets.only(bottom: 18, left: 16, right: 16),
        child: Row(children: [
          _coworker != null
              ? ContactCircle.withCoworkerAndDiameter([], [], _coworker, 60)
              : ContactCircle.forSMS(convo.contacts, convo.crmContacts,
                  convo.isGroup, convo.isBroadcast),
          Expanded(
              child: Container(
                  decoration: BoxDecoration(color: Colors.transparent),
                  child: Row(
                    children: [
                      Expanded(
                          child: Wrap(runSpacing: 4, children: [
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text(convoLabel,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16))),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                                margin: EdgeInsets.only(top: 4),
                                decoration: BoxDecoration(
                                  color: Color.fromARGB(255, 243, 242, 242),
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(4)),
                                ),
                                padding: EdgeInsets.only(
                                    left: 6, right: 6, top: 2, bottom: 2),
                                child: Text(
                                    getDateTime(date) +
                                        " \u2014 " +
                                        convo.message!.message,
                                    style: smallTextStyle,
                                    maxLines: 1,
                                    softWrap: true,
                                    overflow: TextOverflow.ellipsis))),
                        if (chatsVM.selectedDepartmentId ==
                            DepartmentIds.AllMessages)
                          _departmentTag()
                      ])),
                      if (convo.unread > 0)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8.0),
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: informationBlue),
                        ),
                      if (convo.message!.messageStatus == "offline")
                        Icon(
                          Icons.error_outline,
                          color: Colors.red,
                        )
                    ],
                  )))
        ]));
  }
}
