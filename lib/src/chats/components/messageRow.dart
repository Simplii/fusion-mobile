import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/chats/components/messageBody.dart';
import 'package:fusion_mobile_revamped/src/chats/components/pictureMessageBody.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/conversation.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/components/popup_menu.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:intl/intl.dart' as intl;
import 'package:overlay_support/overlay_support.dart';

class MessageRow extends StatelessWidget {
  final SMSMessage message;
  final SMSConversation conversation;
  final DateTime messageTime;
  const MessageRow({
    required this.message,
    required this.conversation,
    required this.messageTime,
    super.key,
  });

  Contact _getContactAvatar(String from) {
    Contact contact = Contact.fake(from);
    var matchedNumber = conversation.contacts.last.phoneNumbers
        .where((num) => num['number'] == message.from)
        .firstOrNull;
    return matchedNumber != null ? conversation.contacts.last : contact;
  }

  Contact _getAvatar(String from, bool isMe) {
    final FusionConnection fusionConnection = FusionConnection.instance;
    if (isMe) {
      //FIXME: figure out unknown coworker
      return message.user == null || !message.user!.contains("@")
          ? Contact.fake(from, firstName: "", lastName: "")
          : fusionConnection.coworkers
              .lookupCoworker(
                  "${message.user?.split('@')[0]}@${fusionConnection.getDomain()}")
              ?.toContact();
    } else {
      return _getContactAvatar(from);
    }
  }

  _openFailedMessageDialog(BuildContext context) {
    return showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext context) => PopupMenu(
              customLabel: Text(
                'Your message was not sent, Tap "Try Again" to send this message',
                style: TextStyle(
                    color: smoke,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.5),
                textAlign: TextAlign.center,
              ),
              bottomChild: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _tryResendFailedMessage(context),
                      child: Text(
                        "Try Again",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ));
  }

  Future<void> _tryResendFailedMessage(BuildContext context) async {
    FusionConnection _fusionConnection = FusionConnection.instance;
    Navigator.pop(context);
    await _fusionConnection.checkInternetConnection();
    if (!_fusionConnection.internetAvailable) {
      toast("unable to connect to the internet".toUpperCase());
    } else {
      await _fusionConnection.messages.resendFailedMessage(message);
      //TODO:
      // setState(() {
      //   _messages.removeWhere((msg) => msg.id == message.id);
      // });

      // _fusionConnection!.messages.sendMessage(message.message, _conversation!,
      //     _selectedGroupId, null, _setOnMessagePosted, () => null, null);
    }
  }

  _openScheduledMessage(BuildContext context) {
    return showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext context) {
          DateTime date = DateTime.parse(message.scheduledAt!).toLocal();
          intl.DateFormat dateFormatter = intl.DateFormat('MMM d,');
          return PopupMenu(
            label: "Scheduled Message",
            bottomChild: Container(
              height: 150,
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Message will be sent on " +
                        dateFormatter.add_jm().format(date).toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      height: 1.5,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                        border: Border(
                      bottom: BorderSide(color: lightDivider, width: 1),
                      top: BorderSide(color: lightDivider, width: 1),
                    )),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        //TODO:
                        // setState(() {
                        //   _messages.removeWhere((msg) => msg.id == message.id);
                        //   _fusionConnection!.messages.deleteMessage(
                        //       this._message!.id, _selectedGroupId);
                        // });
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        "Cancel Message",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  Widget UserAvatar() {
    return Container(
      constraints: BoxConstraints(
          maxWidth: message.typingUsers.length * 40, maxHeight: 40),
      margin: EdgeInsets.symmetric(horizontal: 10),
      child: ListView.builder(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        itemCount: message.typingUsers.length,
        itemBuilder: (context, index) {
          FusionConnection fusionConnection = FusionConnection.instance;
          Contact contact = message.typingUsers[index] == "test@SimpliiDev"
              ? Contact.fake("801897133")
              : fusionConnection.coworkers
                  .getCowworker(message.typingUsers[index])
                  ?.toContact();
          return Align(
            widthFactor: 0.4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: SizedBox(
                height: 40,
                width: 40,
                child:
                    ContactCircle.withDiameterAndMargin([contact], [], 44, 0),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getTypingUserName() {
    String title = "";
    FusionConnection fusionConnection = FusionConnection.instance;
    if (message.typingUsers.length > 2) {
      return title = "Several people are typing...";
    }
    for (var element in message.typingUsers) {
      Coworker? co = fusionConnection.coworkers.getCowworker(element);
      if (title.isNotEmpty) {
        title += " & ${co?.firstName}";
      } else {
        title = "${co?.firstName}";
      }
    }
    return message.typingUsers.length > 1
        ? title + ' are typing...'
        : title + ' is typing...';
  }

  @override
  Widget build(BuildContext context) {
    final bool isMe = message.from == conversation.myNumber;
    final bool isPicture =
        message.mime != null && message.mime.toString().contains('image');
    final double maxWidth =
        (MediaQuery.of(context).size.width - (isMe ? 0 : 40)) * 0.8;
    final Contact matchedContact = _getAvatar(message.from, isMe);
    final TextStyle nameTextStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: char,
    );
    final timeTextStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: smoke,
    );
    bool scheduledMessage = message.scheduledAt != null
        ? DateTime.parse(message.scheduledAt!).toLocal().isAfter(DateTime.now())
        : false;
    return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          textDirection: isMe ? TextDirection.ltr : TextDirection.rtl,
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      message.typingUsers.isNotEmpty
                          ? LimitedBox(
                              maxWidth: MediaQuery.of(context).size.width - 165,
                              child: Text(_getTypingUserName()))
                          : Text(
                              matchedContact.id.isNotEmpty
                                  ? "${matchedContact.name!.toTitleCase()}"
                                  : "${message.from.formatPhone()}",
                            ),
                      SizedBox(
                        width: 4,
                      ),
                      if (message.typingUsers.isEmpty)
                        Text(
                          matchedContact.id.isNotEmpty
                              ? "${intl.DateFormat.jm().format(messageTime)}"
                              : "${intl.DateFormat.jm().format(messageTime)}",
                          style: timeTextStyle,
                        )
                    ],
                  ),
                if (isMe)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          message.messageStatus == 'delivered'
                              ? Icon(Icons.check, size: 15, color: smoke)
                              : (message.messageStatus == 'failed' ||
                                      message.messageStatus == 'offline')
                                  ? Container(
                                      padding: EdgeInsets.only(bottom: 1),
                                      child: Icon(
                                        Icons.clear,
                                        size: 15,
                                        color: crimsonDark,
                                      ))
                                  : Container(),
                          Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width - 90,
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                matchedContact.name?.toUpperCase() ?? "",
                                style: nameTextStyle,
                                textWidthBasis: TextWidthBasis.longestLine,
                                overflow: TextOverflow.ellipsis,
                              )),
                          Text(intl.DateFormat.jm().format(messageTime),
                              style: timeTextStyle)
                        ],
                      ),
                      if (message.errorMessage.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 1, bottom: 2),
                            child: Text(message.errorMessage,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: smoke,
                                    fontWeight: FontWeight.w500)))
                    ],
                  ),
                Row(
                  children: [
                    Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width - 90),
                        child: isPicture
                            ? PictureMessageBody(isMe: isMe, message: message)
                            : MessageBody(
                                isMe: isMe,
                                maxWidth: maxWidth,
                                isTyping: message.id == "-3",
                                messageText: message.message)),
                    if (message.messageStatus == "offline")
                      IconButton(
                          padding: EdgeInsets.only(left: 5),
                          constraints: BoxConstraints(),
                          onPressed: () => _openFailedMessageDialog(context),
                          icon: Icon(Icons.error_outline, color: Colors.red)),
                    if (scheduledMessage)
                      IconButton(
                          padding: EdgeInsets.only(left: 5),
                          constraints: BoxConstraints(),
                          onPressed: () => _openScheduledMessage(context),
                          icon: Icon(Icons.schedule, color: smoke)),
                  ],
                ),
              ],
            ),
            SizedBox(width: 8),
            message.id == "-3"
                ? UserAvatar()
                : ContactCircle.withDiameterAndMargin(
                    [matchedContact], [], 44, 0),
          ],
        ));
  }
}
