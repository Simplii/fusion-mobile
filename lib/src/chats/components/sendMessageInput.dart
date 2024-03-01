import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/conversation.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:intl/intl.dart';

class SendMessageInput extends StatefulWidget {
  final ConversationVM conversationVM;
  final ChatsVM? chatsVM;
  final SMSConversation conversation;
  const SendMessageInput({
    required this.conversationVM,
    required this.conversation,
    this.chatsVM,
    super.key,
  });

  @override
  State<SendMessageInput> createState() => _SendMessageInputState();
}

class _SendMessageInputState extends State<SendMessageInput> {
  ConversationVM get _conversationVM => widget.conversationVM;
  ChatsVM? get _cahtsVM => widget.chatsVM;
  SMSConversation get _conversation => widget.conversation;
  FusionConnection fusionConnection = FusionConnection.instance;
  TextEditingController _messageInputController = TextEditingController();

  //FIXME: clean up
  int textLength = 0;
  bool isSavedMessage = false;
  bool loading = false;
  _hasEnteredMessage() {
    return _conversationVM.mediaToSend.length > 0 ||
        _messageInputController.value.text.trim().length > 0;
  }

  @override
  Widget build(BuildContext context) {
    Coworker? _assignedTo = _conversation.assigneeUid != null
        ? fusionConnection.coworkers.getCowworker(
            _conversation.assigneeUid!.toLowerCase(),
          )
        : null;
    DateFormat dateFormatter = DateFormat('MMM d,');

    return Container(
      decoration: BoxDecoration(color: particle),
      padding: EdgeInsets.only(
        top: _conversationVM.scheduledAt != null ? 0 : 12,
        left: 8,
        bottom:
            (iphoneIsLarge() && MediaQuery.of(context).viewInsets.bottom == 0)
                ? 32
                : 12,
        right: 8,
      ),
      child: Column(
        children: [
          if (_assignedTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(
                    "Assigned to: ${_assignedTo.firstName} ${_assignedTo.lastName}",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _assignedTo.uid.toLowerCase() !=
                                fusionConnection
                                    .getUid()
                                    .toString()
                                    .toLowerCase()
                            ? crimsonDark
                            : coal),
                  ),
                ],
              ),
            ),
          if (_conversationVM.scheduledAt != null)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.black,
                    width: 1.0,
                  ),
                ),
              ),
              margin: EdgeInsets.only(bottom: 10, left: 20, right: 20),
              child: Row(
                children: [
                  Expanded(
                      child: Text(
                    "Will be sent: " +
                        dateFormatter
                            .add_jm()
                            .format(_conversationVM.scheduledAt!)
                            .toString(),
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  )),
                  IconButton(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      constraints: BoxConstraints(),
                      onPressed: () {
                        // setState(() {
                        //   secheduleIsSet = null;
                        // });
                      },
                      icon: Icon(
                        Icons.remove_circle_outline_rounded,
                        color: Colors.red,
                      ))
                ],
              ),
            ),
          Row(
            children: [
              FusionDropdown(
                  selectedNumber: "",
                  onChange: (String value) {
                    if (value == "schedule") {
                      // _openMessageScheduling();
                    } else {
                      // _attachImage(value);
                    }
                  },
                  value: "",
                  options: [
                    ["Camera", "camera"],
                    ["Record Videos", "recordvideo"],
                    ["Videos", "videos"],
                    ["Photos", "photos"],
                    ["Schedule Message", "schedule"]
                  ],
                  label: "Other Options",
                  button: Container(
                      height: 28,
                      width: 22,
                      margin: EdgeInsets.only(right: 12, left: 4, top: 0),
                      child: Icon(
                        Icons.add,
                        size: 28,
                        color: smoke,
                      ))),
              Expanded(
                child: Stack(
                  children: [
                    if (_conversationVM.mediaToSend.isNotEmpty)
                      Container(
                        height: 120,
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                                color: Color.fromARGB(255, 229, 227, 227),
                                width: 1),
                            borderRadius:
                                BorderRadius.only(topLeft: Radius.circular(8))),
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          // children: _mediaToSendViews(),
                          children: [],
                        ),
                      ),
                    Container(
                      padding: EdgeInsets.only(left: 14, right: 14, top: 0),
                      margin: EdgeInsets.only(
                          top:
                              _conversationVM.mediaToSend.isNotEmpty ? 119 : 0),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                              color: Color.fromARGB(255, 229, 227, 227),
                              width: 1),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(
                                _conversationVM.mediaToSend.isNotEmpty ? 0 : 8),
                            bottomLeft: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                          )),
                      child: TextField(
                        textAlignVertical: TextAlignVertical.center,
                        textCapitalization: TextCapitalization.sentences,
                        controller: _messageInputController,
                        maxLines: 10,
                        minLines: 1,
                        onChanged: (String changedTo) {
                          if (_messageInputController.text.length - textLength >
                                  1 &&
                              !isSavedMessage &&
                              _messageInputController.text
                                  .contains("https://fusioncom.co/media")) {
                            // SharedPreferences.getInstance().then(
                            //   (SharedPreferences prefs) {
                            //     String imageUri =
                            //         prefs.getString("copiedImagePath")!;
                            //     if (imageUri.length == 0) {
                            //       this.setState(() {
                            //         _saveLocalState(changedTo);
                            //       });
                            //     } else {
                            //       // setState(() {
                            //       //   _mediaToSend.add(XFile('$imageUri'));
                            //       //   _messageInputController.text = '';
                            //       //   Clipboard.setData(ClipboardData(text: ''));
                            //       // });
                            //     }
                            //   },
                            // );
                          } else {
                            // setState(() {
                            //   _saveLocalState(changedTo);
                            // });
                          }
                          textLength = _messageInputController.text.length;
                        },
                        decoration: InputDecoration(
                            suffixIcon: IconButton(
                              icon: Icon(Icons.chat_bubble_outline_outlined),
                              onPressed: () => print("_openQuickResponses"),
                            ),
                            contentPadding: EdgeInsets.only(
                                left: 0, right: 0, top: 2, bottom: 2),
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                                fontSize: 14,
                                color: Color.fromARGB(255, 153, 148, 149)),
                            hintText: "Message"),
                      ),
                    )
                  ],
                ),
              ),
              Container(
                height: 40,
                width: 40,
                margin: EdgeInsets.only(left: 8),
                child: IconButton(
                  padding: EdgeInsets.all(0),
                  icon: loading
                      ? Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: crimsonDark,
                          ),
                          child: Transform.scale(
                              scale: 0.5,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              )))
                      : Image.asset(
                          _hasEnteredMessage()
                              ? "assets/icons/send_active.png"
                              : "assets/icons/send.png",
                          height: 40,
                          width: 40),
                  onPressed: loading ? null : () => print("_sendMessage"),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}
