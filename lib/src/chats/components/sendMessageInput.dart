import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/conversation.dart';
import 'package:fusion_mobile_revamped/src/components/date_time_picker.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/components/popup_menu.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

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

  //TODO: Switch to copy image in natve since its not supported by flutter
  Timer? _debounceMessageInput;
  int textLength = 0;
  bool isSavedMessage = false;
  List<String> _savedImgPaths = [];
  _saveLocalState(lastMessage) {
    if (lastMessage.toString().trim().isNotEmpty &&
        _debounceMessageInput == null) {
      _conversationVM.sendTypingStatus();
    }
    if (_debounceMessageInput?.isActive ?? false)
      _debounceMessageInput!.cancel();
    _debounceMessageInput = Timer(const Duration(milliseconds: 1000), () {
      SharedPreferences.getInstance().then((SharedPreferences prefs) {
        prefs.setString("${_conversation.hash}_savedMessage", lastMessage);
      });
      if (lastMessage.toString().trim().isNotEmpty) {
        _conversationVM.sendTypingStatus();
      }
    });
  }

  _saveImageLocally(XFile image) async {
    final String path = await getApplicationDocumentsDirectory().toString();

    String imgExt = p.extension(path);
    String imagePath =
        "${_conversation!.hash}_savedImage_" + randomString(10) + "." + imgExt;

    _savedImgPaths.add(imagePath);

    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setStringList("${_conversation!.hash}_savedImages", _savedImgPaths);
    });

    image.saveTo('$path/$imagePath');
  }

  @override
  void dispose() {
    _debounceMessageInput?.cancel();
    super.dispose();
  }

  _hasEnteredMessage() {
    return _conversationVM.mediaToSend.length > 0 ||
        _messageInputController.value.text.trim().length > 0;
  }

  _openMessageScheduling() {
    showModalBottomSheet(
        useRootNavigator: true, //to replace previous route
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext context) => PopupMenu(
              bottomChildSymmetricPadding: 0,
              label: "Schedule Message",
              bottomChild: DateTimePicker(
                  iosStyle: true,
                  height: 240,
                  onComplete: (DateTime? selectedDateTime) {
                    setState(() {
                      if (selectedDateTime != null)
                        _conversationVM.scheduledAt = selectedDateTime;
                    });
                  }),
            ));
  }

  _mediaToSendViews() {
    return _conversationVM.mediaToSend
        .map((XFile media) {
          return Container(
              margin: EdgeInsets.only(right: 8),
              child: Stack(alignment: Alignment.topRight, children: [
                ClipRRect(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4)),
                    child: (media.name.toLowerCase().contains("png") ||
                            media.name.toLowerCase().contains("gif") ||
                            media.name.toLowerCase().contains("jpg") ||
                            media.name.toLowerCase().contains("jpeg") ||
                            media.name.toLowerCase().contains("jiff"))
                        ? Image.file(File(media.path), height: 100)
                        : Container(
                            height: 100,
                            width: 100,
                            color: particle,
                            alignment: Alignment.center,
                            child: Text("attachment",
                                style: TextStyle(color: coal)))),
                GestureDetector(
                    onTap: () {
                      this.setState(() {
                        _conversationVM.mediaToSend.remove(media);
                      });
                    },
                    child: Container(
                        alignment: Alignment.center,
                        margin: EdgeInsets.only(top: 8, right: 8),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                            color: char,
                            borderRadius: BorderRadius.all(Radius.circular(11)),
                            border: Border.all(color: Colors.white, width: 2)),
                        child: Icon(CupertinoIcons.xmark,
                            color: Colors.white, size: 12)))
              ]));
        })
        .toList()
        .cast<Widget>();
  }

  void _attachImage(String source) {
    final ImagePicker _picker = ImagePicker();
    if (source == "camera") {
      _picker.pickImage(source: ImageSource.camera).then((XFile? file) {
        if (file != null) {
          setState(() {
            _conversationVM.mediaToSend.add(file);
            _saveImageLocally(file);
          });
        }
      });
    } else if (source == 'videos') {
      _picker.pickVideo(source: ImageSource.gallery).then((XFile? file) {
        if (file != null) {
          setState(() {
            _conversationVM.mediaToSend.add(file);
            _saveImageLocally(file);
          });
        }
      });
    } else if (source == 'recordvideo') {
      _picker.pickVideo(source: ImageSource.camera).then((XFile? file) {
        if (file != null) {
          setState(() {
            _conversationVM.mediaToSend.add(file);
            _saveImageLocally(file);
          });
        }
      });
    } else {
      _picker.pickMultiImage().then((List<XFile> images) {
        this.setState(() {
          if (images != null) {
            images.forEach((file) {
              this.setState(() {
                _conversationVM.mediaToSend.add(file);
                _saveImageLocally(file);
              });
            });
          }
        });
      });
    }
  }

  void _openQuickResponses() {
    List<String?> messages = _conversationVM.quickResponses
        .map(
          (qr) => qr.message,
        )
        .toList();
    showModalBottomSheet(
        backgroundColor: Colors.transparent,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        context: context,
        isScrollControlled: true,
        builder: (context) => PopupMenu(
            label: "Quick Responses",
            bottomChild: messages.length > 0
                ? Container(
                    height: MediaQuery.of(context).size.height * 0.3,
                    child: ListView.separated(
                        itemBuilder: (BuildContext context, int index) {
                          String renderedQR = _conversationVM
                              .renderQuickResponse(messages[index]);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (!_conversation.isGroup &&
                                    _conversation.contacts.isNotEmpty) {
                                  _messageInputController.text = renderedQR;
                                } else {
                                  _messageInputController.text =
                                      messages[index] ?? "";
                                }
                              });
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: EdgeInsets.only(top: index == 0 ? 8 : 0),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  renderedQR,
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) => Divider(
                              color: lightDivider,
                              thickness: 1.0,
                            ),
                        itemCount: messages.length),
                  )
                : Container(
                    height: 100,
                    child: Center(
                        child: Text("no quick responses found".toTitleCase(),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center)),
                  )));
  }

  @override
  Widget build(BuildContext context) {
    Coworker? _assignedTo = _conversation.assigneeUid != null
        ? fusionConnection.coworkers.getCoworker(
            _conversation.assigneeUid!.toLowerCase(),
          )
        : null;
    DateFormat dateFormatter = DateFormat('MMM d,');

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.fastOutSlowIn,
          height: _conversationVM.showLargeMMSErrorMessage ? 40 : 0,
          child: Row(
            children: [
              Expanded(
                child: Container(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(left: 10),
                    color: coal,
                    child: Text(
                      "Sorry you don't have Large MMS turned on",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    )),
              )
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(color: particle),
          padding: EdgeInsets.only(
            top: _conversationVM.scheduledAt != null ? 0 : 12,
            left: 8,
            bottom: (iphoneIsLarge() &&
                    MediaQuery.of(context).viewInsets.bottom == 0)
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
                            setState(() {
                              _conversationVM.scheduledAt = null;
                            });
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
                          _openMessageScheduling();
                        } else {
                          _attachImage(value);
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
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8))),
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: _mediaToSendViews(),
                            ),
                          ),
                        Container(
                          padding: EdgeInsets.only(left: 14, right: 14, top: 0),
                          margin: EdgeInsets.only(
                              top: _conversationVM.mediaToSend.isNotEmpty
                                  ? 119
                                  : 0),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color: Color.fromARGB(255, 229, 227, 227),
                                  width: 1),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(
                                    _conversationVM.mediaToSend.isNotEmpty
                                        ? 0
                                        : 8),
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
                              if (_messageInputController.text.length -
                                          textLength >
                                      1 &&
                                  !isSavedMessage &&
                                  _messageInputController.text
                                      .contains("https://fusioncom.co/media")) {
                                //TODO: clean up and move to native
                                SharedPreferences.getInstance().then(
                                  (SharedPreferences prefs) {
                                    String imageUri =
                                        prefs.getString("copiedImagePath")!;
                                    if (imageUri.length == 0) {
                                      this.setState(() {
                                        _saveLocalState(changedTo);
                                      });
                                    } else {
                                      setState(() {
                                        _conversationVM.mediaToSend
                                            .add(XFile('$imageUri'));
                                        _messageInputController.text = '';
                                        Clipboard.setData(
                                            ClipboardData(text: ''));
                                      });
                                    }
                                  },
                                );
                              } else {
                                setState(() {
                                  _saveLocalState(changedTo);
                                });
                              }
                              textLength = _messageInputController.text.length;
                            },
                            decoration: InputDecoration(
                                suffixIcon: IconButton(
                                  icon:
                                      Icon(Icons.chat_bubble_outline_outlined),
                                  onPressed: _openQuickResponses,
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
                      icon: _conversationVM.sendingMessage
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
                      onPressed: _conversationVM.sendingMessage
                          ? null
                          : () {
                              _conversationVM.sendMessage(
                                conversation: _conversation,
                                messageText:
                                    _messageInputController.value.text.trim(),
                              );
                              setState(() {
                                _messageInputController.text = "";
                                _saveLocalState("");
                              });
                            },
                    ),
                  )
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
