import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/contacts/contact_profile_view.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../backend/fusion_connection.dart';
import '../styles.dart';
import '../utils.dart';

class SMSConversationView extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final SMSConversation _smsConversation;
  final Softphone _softphone;

  SMSConversationView(
      this._fusionConnection, this._softphone, this._smsConversation,
      {Key key})
      : super(key: key);

  static openConversation(
      BuildContext context,
      FusionConnection fusionConnection,
      List<Contact> contacts,
      List<CrmContact> crmContacts,
      Softphone softphone,
      String phoneNumber) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => SMSConversationView(
            fusionConnection,
            softphone,
            SMSConversation.build(
                contacts: contacts,
                crmContacts: crmContacts,
                myNumber: fusionConnection.smsDepartments
                    .getDepartment("-2")
                    .numbers[0],
                number: phoneNumber)));
  }

  @override
  State<StatefulWidget> createState() => _SMSConversationViewState();
}

class _SMSConversationViewState extends State<SMSConversationView> {
  FusionConnection get _fusionConnection => widget._fusionConnection;

  Softphone get _softphone => widget._softphone;

  SMSConversation get _conversation => widget._smsConversation;
  TextEditingController _messageInputController = TextEditingController();
  bool _loaded = false;
  List<XFile> _mediaToSend = [];
  List<SMSMessage> _messages = [];
  List<String> _savedImgPaths = [];

  Timer _debounceMessageInput;

  initState() {
    super.initState();
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      String savedMessage =
          prefs.getString(_conversation.hash + "_savedMessage");
      _messageInputController.text = savedMessage;

      final String path = getApplicationDocumentsDirectory().toString();
      List<String> savedImgs =
          prefs.getStringList(_conversation.hash + "_savedImages");
      if (savedImgs != null) {
        savedImgs.map((e) =>
        {
          _mediaToSend.add(XFile("$path/$e"))
        });
      }
    });

    if (_fusionConnection.smsDepartments.lookupRecord("-2") != null) {
      _loaded = true;
    }
    _fusionConnection.smsDepartments.getDepartments((List<SMSDepartment> list) {
      if (!mounted) return;
      this.setState(() {
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _debounceMessageInput?.cancel();
    super.dispose();
  }

  _openMedia(SMSMessage message) {
    showModalBottomSheet(
        context: context,
        backgroundColor: translucentBlack(0.3),
        isScrollControlled: true,
        builder: (context) {
          return _mediaGallery(message);
        });
  }

  _mediaGallery(SMSMessage activeMessage) {
    List<SMSMessage> galleryItems = _messages
        .where((SMSMessage message) {
          return message.mime != null && message.mime.contains("image") ||
              message.mime.contains("video");
        })
        .toList()
        .cast<SMSMessage>();
    int currentPage = 0;

    int index = 0;
    for (SMSMessage m in galleryItems) {
      if (m == activeMessage) currentPage = index;
      index += 1;
    }

    PageController pageController = PageController(initialPage: currentPage);

    return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
            decoration: BoxDecoration(color: Colors.transparent),
            child: PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                SMSMessage message = galleryItems[index];
                if (message.mime.contains("image"))
                  return PhotoViewGalleryPageOptions(
                    imageProvider: NetworkImage(message.message),
                    initialScale: PhotoViewComputedScale.contained * 0.8,
                    heroAttributes:
                        PhotoViewHeroAttributes(tag: galleryItems[index].id),
                  );
                else
                  return PhotoViewGalleryPageOptions.customChild(
                      initialScale: PhotoViewComputedScale.contained * 0.8,
                      heroAttributes:
                          PhotoViewHeroAttributes(tag: galleryItems[index].id),
                      child: VideoPlayer(
                          VideoPlayerController.network(message.message)));
              },
              itemCount: galleryItems.length,
              loadingBuilder: (context, event) => Center(
                child: Container(
                  width: 20.0,
                  height: 20.0,
                  child: CircularProgressIndicator(
                    value: event == null
                        ? 0
                        : event.cumulativeBytesLoaded /
                            event.expectedTotalBytes,
                  ),
                ),
              ),
              backgroundDecoration: BoxDecoration(color: Colors.transparent),
              pageController: pageController,
              onPageChanged: (int page) {},
            )));
  }

  _header() {
    String myImageUrl = _fusionConnection.myAvatarUrl();

    return Column(children: [
      Center(
          child: Container(
              decoration: BoxDecoration(
                  color: halfSmoke,
                  borderRadius: BorderRadius.all(Radius.circular(3))),
              width: 36,
              height: 5)),
      Row(children: [
        ContactCircle(_conversation.contacts, _conversation.crmContacts),
        Expanded(
            child: Column(children: [
          Align(
              alignment: Alignment.centerLeft,
              child: Text(_conversation.contactName(), style: headerTextStyle)),
          Align(
              alignment: Alignment.centerLeft,
              child: Text(_conversation.number.formatPhone(),
                  style: subHeaderTextStyle))
        ])),
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
              widget._softphone.makeCall(_conversation.number);
            }),
        FusionDropdown(
            onChange: (String chosen) {
              if (chosen == "contactprofile") {
                Future.delayed(Duration(milliseconds: 10), () {
                  showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => ContactProfileView(
                          _fusionConnection,
                          _softphone,
                          _conversation.contacts[0]));
                });
              } else {
                Future.delayed(Duration(milliseconds: 10), () {
                  _openMedia(null);
                });
              }
            },
            value: "",
            options: _conversation.contacts.length > 0
                ? [
                    ["Open Contact Profile", "contactprofile"],
                    ["Shared Media", "sharedmedia"]
                  ]
                : [
                    ["Shared Media", "sharedmedia"]
                  ],
            label: _conversation.contactName(),
            button: IconButton(
                iconSize: 32,
                icon: Image.asset(
                  "assets/icons/three_dots.png",
                  width: 4,
                  height: 16,
                )))
      ]),
      Row(children: [horizontalLine(16)]),
      Row(children: [
        Align(alignment: Alignment.centerRight, child: _departmentName()),
        Expanded(child: Container()),
        Container(
          child: Align(
              alignment: Alignment.centerRight, child: _myNumberDropdown()),
        ),
        Align(
            alignment: Alignment.centerRight,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        image: DecorationImage(
                            fit: BoxFit.fill,
                            image: (myImageUrl != null
                                ? NetworkImage(myImageUrl)
                                : Image.asset("assets/blank_avatar.png",
                                    height: 32, width: 32)))))))
      ])
    ]);
  }

  _allMyNumbers() {
    SMSDepartment dept = _fusionConnection.smsDepartments.lookupRecord("-2");
    List<List<String>> opts = [];

    for (String number in dept.numbers) {
      opts.add([number.formatPhone(), number.onlyNumbers()]);
    }

    return opts;
  }

  _allTheirNumbers() {
    List<List<String>> opts = [];
    Map<String, String> numbers = {
      _conversation.number.onlyNumbers(): _conversation.number.onlyNumbers()
    };

    for (Contact c in _conversation.contacts) {
      if (c.phoneNumbers != null) {
        for (Map<String, dynamic> number in c.phoneNumbers) {
          numbers[("" + number['number'].toString()).onlyNumbers()] =
              number['number'];
        }
      }
    }

    for (CrmContact c in _conversation.crmContacts) {
      if (c.phone_number != null) {
        numbers[c.phone_number.onlyNumbers()] = c.phone_number;
      }
    }

    for (String number in numbers.keys) {
      opts.add([number.formatPhone(), number.onlyNumbers()]);
    }

    return opts;
  }

  _myNumberDropdown() {
    return Container(
        decoration: dropdownDecoration,
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.only(top: 0, bottom: 0, right: 0, left: 8),
        height: 36,
        child: FusionDropdown(
            value: _conversation.myNumber,
            options: _allMyNumbers(),
            onChange: (String newNumber) {
              this.setState(() {
                _conversation.myNumber = newNumber;
              });
            },
            label: "Your phone number"));
  }

  _departmentName() {
    SMSDepartment department = _fusionConnection.smsDepartments
        .getDepartmentByPhoneNumber(_conversation.myNumber);
    return Container(
        decoration: dropdownDecoration,
        padding: EdgeInsets.only(top: 0, bottom: 0, right: 0, left: 8),
        height: 36,
        child: FusionDropdown(
            style: TextStyle(fontSize: 14,fontWeight: FontWeight.w500),
            disabled: true,
            value: department.groupName.toUpperCase(),
            options: [],
            onChange: null,
            label: "Department"));
  }

  _saveImageLocally(XFile image) async {
    final String path = await getApplicationDocumentsDirectory().toString();

    String imgExt = p.extension(path);
    String imagePath =
        _conversation.hash + "_savedImage_" + randomString(10) + "." + imgExt;

    _savedImgPaths.add(imagePath);

    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setStringList(_conversation.hash + "_savedImages", _savedImgPaths);
    });

    image.saveTo('$path/$imagePath');
  }

  _attachImage(String source) {
    final ImagePicker _picker = ImagePicker();
    if (source == "camera") {
      _picker.pickImage(source: ImageSource.camera).then((XFile file) {
        if (file != null) {
          this.setState(() {
            _mediaToSend.add(file);
            _saveImageLocally(file);
          });
        }
      });
    } else if (source == 'videos') {
      _picker.pickVideo(source: ImageSource.gallery).then((XFile file) {
        if (file != null) {
          this.setState(() {
            _mediaToSend.add(file);
            _saveImageLocally(file);
          });
        }
      });
    } else if (source == 'recordvideo') {
      _picker.pickVideo(source: ImageSource.camera).then((XFile file) {
        if (file != null) {
          this.setState(() {
            _mediaToSend.add(file);
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
                _mediaToSend.add(file);
                _saveImageLocally(file);
              });
            });
          }
        });
      });
    }
  }

  _mediaToSendViews() {
    return _mediaToSend
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
                    child: (
                        media.name.toLowerCase().contains("png")
                            || media.name.toLowerCase().contains("gif")
                            || media.name.toLowerCase().contains("jpg")
                            || media.name.toLowerCase().contains("jpeg")
                            || media.name.toLowerCase().contains("jiff")
                    )
                        ?  Image.file(File(media.path), height: 100)
                        : Container(height: 100,width:100,color:particle,
                        alignment: Alignment.center,
                        child: Text("attachment", style: TextStyle(color:coal)))),
                GestureDetector(
                    onTap: () {
                      this.setState(() {
                        _mediaToSend.remove(media);
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

  _saveLocalState(lastMessage) {
    if (_debounceMessageInput?.isActive ?? false)
      _debounceMessageInput.cancel();
    _debounceMessageInput = Timer(const Duration(milliseconds: 1000), () {
      SharedPreferences.getInstance().then((SharedPreferences prefs) {
        prefs.setString(_conversation.hash + "_savedMessage", lastMessage);
      });
    });
  }

  _sendMessageInput() {
    return Container(
        decoration: BoxDecoration(color: particle),
        padding: EdgeInsets.only(
            top: 12,
            left: 8,
            bottom: (iphoneIsLarge() &&
                    MediaQuery.of(context).viewInsets.bottom == 0)
                ? 32
                : 12,
            right: 8),
        child: Row(children: [
          FusionDropdown(
              onChange: (String value) {
                _attachImage(value);
              },
              value: "",
              options: [
                ["Camera", "camera"],
                ["Record Videos", "recordvideo"],
                ["Videos", "videos"],
                ["Photos", "photos"]
              ],
              label: "From which source?",
              button: Container(
                  height: 18,
                  width: 22,
                  margin: EdgeInsets.only(right: 12, left: 4, top: 0),
                  child: IconButton(
                      padding: EdgeInsets.all(0),
                      icon: Image.asset("assets/icons/camera.png",
                          height: 18, width: 22)))),
          Expanded(
              child: Stack(children: [
            if (_mediaToSend != null && _mediaToSend.length > 0)
              Container(
                  height: 120,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                          color: Color.fromARGB(255, 229, 227, 227), width: 1),
                      borderRadius:
                          BorderRadius.only(topLeft: Radius.circular(8))),
                  child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: _mediaToSendViews())),
            Container(
                padding: EdgeInsets.only(left: 14, right: 14, top: 0),
                margin: EdgeInsets.only(top: _mediaToSend.length > 0 ? 119 : 0),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                        color: Color.fromARGB(255, 229, 227, 227), width: 1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(_mediaToSend.length > 0 ? 0 : 8),
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    )),
                child: TextField(
                  textCapitalization: TextCapitalization.sentences,
                  controller: _messageInputController,
                  maxLines: 10,
                  minLines: 1,
                  onChanged: (String changedTo) {
                    _saveLocalState(changedTo);
                  },
                  decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.only(left: 0, right: 0, top: 2, bottom: 2),
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color.fromARGB(255, 153, 148, 149)),
                      hintText: "Message"),
                ))
          ])),
          Container(
              height: 40,
              width: 40,
              margin: EdgeInsets.only(left: 8),
              child: IconButton(
                padding: EdgeInsets.all(0),
                icon: Image.asset(
                    _hasEnteredMessage()
                        ? "assets/icons/send_active.png"
                        : "assets/icons/send.png",
                    height: 40,
                    width: 40),
                onPressed: _sendMessage,
              ))
        ]));
  }

  _hasEnteredMessage() {
    return _mediaToSend.length > 0 ||
        _messageInputController.value.text.trim().length > 0;
  }

  _sendMessage() {
    setState(() {
      if (_messageInputController.value.text.trim().length > 0) {
        _fusionConnection.messages
            .sendMessage(_messageInputController.value.text, _conversation);
        _messageInputController.text = "";
      }
      if (_mediaToSend.length > 0) {
        for (XFile file in _mediaToSend) {
          _fusionConnection.messages.sendMediaMessage(file, _conversation);
        }
        _mediaToSend = [];
      }
      _saveLocalState("");
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    return Container(
        child: Column(children: [
          Expanded(
              child: Container(
                  decoration: BoxDecoration(color: Colors.transparent),
                  padding: EdgeInsets.only(top: 80, bottom: 0),
                  child: Column(children: [
                    Container(
                        decoration: BoxDecoration(
                            color: particle,
                            borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16))),
                        padding: EdgeInsets.only(
                            top: 10, left: 14, right: 14, bottom: 12),
                        child: _header()),
                    Row(children: [
                      Expanded(
                          child: Container(
                              decoration: BoxDecoration(
                                  color: Color.fromARGB(255, 222, 221, 221)),
                              height: 1))
                    ]),
                    Expanded(
                        child: Container(
                            decoration: BoxDecoration(color: Colors.white),
                            child: Row(children: [
                              Expanded(
                                  child: _loaded
                                      ? ConvoMessagesList(
                                          _fusionConnection, _conversation,
                                          (List<SMSMessage> messages) {
                                          _messages = messages;
                                        }, _openMedia)
                                      : Container())
                            ]))),
                  ]))),
          _sendMessageInput()
        ]),
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom));
  }
}

class ConvoMessagesList extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final SMSConversation _conversation;
  final Function(List<SMSMessage>) _onPulledMessages;
  final Function(SMSMessage) _openMedia;

  ConvoMessagesList(this._fusionConnection, this._conversation,
      this._onPulledMessages, this._openMedia,
      {Key key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _ConvoMessagesListState();
}

class _ConvoMessagesListState extends State<ConvoMessagesList> {
  SMSConversation get _conversation => widget._conversation;

  FusionConnection get _fusionConnection => widget._fusionConnection;

  Function(SMSMessage) get _openMedia => widget._openMedia;
  int lookupState = 0; // 0 - not looking up; 1 - looking up; 2 - got results
  List<SMSMessage> _messages = [];
  String _subscriptionKey;

  String _lookedupNumber = "";
  String _lookedupMyNumber = "";

  @override
  dispose() {
    _clearSubscription();
    super.dispose();
  }

  _clearSubscription() {
    if (_subscriptionKey != null) {
      _fusionConnection.messages.clearSubscription(_subscriptionKey);
      _subscriptionKey = null;
    }
  }

  _addMessage(SMSMessage message) {
    bool matched = false;

    for (SMSMessage savedMessage in _messages) {
      if (savedMessage.id == message.id) {
        matched = true;
      }
    }

    if (!matched) {
      _messages.add(message);
    }
  }

  @override
  _lookupMessages() {
    lookupState = 1;
    _clearSubscription();
    _subscriptionKey = _fusionConnection.messages.subscribe(_conversation,
        (List<SMSMessage> messages) {
      if (!mounted) return;
      this.setState(() {
        for (SMSMessage m in messages) {
          _addMessage(m);
        }
      });
    });
    _fusionConnection.messages.getMessages(_conversation, 200, 0,
        (List<SMSMessage> messages, fromServer) {
      if (!mounted) return;
      this.setState(() {
        if (fromServer) lookupState = 2;
        _messages = messages;
        widget._onPulledMessages(_messages);
      });
    });
  }

  _newConvoMessage() {
    return [
      Container(
          alignment: Alignment.center,
          padding: EdgeInsets.only(bottom: 24, top: 24, left: 48, right: 48),
          //constraints: BoxConstraints(maxWidth: 170),
          child: this.lookupState < 2
              ? Center(child: SpinKitThreeBounce(color: smoke, size: 50))
              : Text(
                  "This is the beginning of your text history with " +
                      _conversation.contactName(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: smoke,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic)))
    ];
  }

  _messagesList() {
    List<Widget> list = [];
    DateTime lastDate;
    Widget toAdd;

    _messages.sort((SMSMessage m1, SMSMessage m2) {
      return m1.unixtime > m2.unixtime ? -1 : 1;
    });

    for (SMSMessage msg in _messages) {
      DateTime thisTime =
          DateTime.fromMillisecondsSinceEpoch(msg.unixtime * 1000);

      if (lastDate == null ||
          thisTime.difference(lastDate).inHours.abs() > 24) {
        lastDate = thisTime;

        if (toAdd != null) {
          list.add(toAdd);
        }

        toAdd = Row(children: [
          horizontalLine(8),
          Container(
              margin: EdgeInsets.only(left: 4, right: 4, bottom: 12, top: 12),
              child: Text(
                DateFormat("E MMM d, y").format(thisTime),
                style: TextStyle(
                    color: char, fontSize: 12, fontWeight: FontWeight.w700),
              )),
          horizontalLine(8)
        ]);
      }
      list.add(SMSMessageView(_fusionConnection, msg, _conversation,
          (SMSMessage message) {
        _openMedia(message);
      }));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (lookupState != 0 &&
        (_conversation.number != _lookedupNumber ||
            _conversation.myNumber != _lookedupMyNumber)) {
      lookupState = 0;
      _messages = [];
    }

    if (lookupState == 0) {
      _lookedupNumber = _conversation.number;
      _lookedupMyNumber = _conversation.myNumber;
      _lookupMessages();
    }

    return ListView(
        children: _messages.length == 0 ? _newConvoMessage() : _messagesList(),
        reverse: true);
  }
}

class SMSMessageView extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final SMSMessage _message;
  final SMSConversation _conversation;
  final Function(SMSMessage) _openMedia;

  SMSMessageView(this._fusionConnection, this._message, this._conversation,
      this._openMedia,
      {Key key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _SMSMessageViewState();
}

class _SMSMessageViewState extends State<SMSMessageView> {
  FusionConnection get _fusionConnection => widget._fusionConnection;

  SMSConversation get _conversation => widget._conversation;

  SMSMessage get _message => widget._message;
  final _searchInputController = TextEditingController();

  _openMedia() {
    widget._openMedia(_message);
  }

  _messageText(String message, TextStyle style) {
    final urlRegExp = new RegExp(
        r"((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?");
    final urlMatches = urlRegExp.allMatches(message).toList();

    int start = 0;
    List<TextSpan> texts = [];

    for (RegExpMatch urlMatch in urlMatches) {
      if (urlMatch.start > start) {
        texts.add(TextSpan(
            text: message.substring(start, urlMatch.start), style: style));
      }
      TapGestureRecognizer recognizer = new TapGestureRecognizer();
      recognizer.onTap = () {
        launch(message.substring(urlMatch.start, urlMatch.end));
      };
      texts.add(TextSpan(
          text: message.substring(urlMatch.start, urlMatch.end),
          style: TextStyle(color: crimsonDark),
          recognizer: recognizer));
      start = urlMatch.end;
    }

    texts.add(TextSpan(text: message.substring(start), style: style));

    return new SelectableText.rich(TextSpan(children: texts));
  }

  _renderMessage() {
    bool isFromMe = _message.from == _conversation.myNumber;
    double maxWidth =
        (MediaQuery.of(context).size.width - (isFromMe ? 0 : 40)) * 0.8;
    return Align(
        alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: _message.mime != null &&
                _message.mime.toString().contains('image')
            ? GestureDetector(
                onTap: _openMedia,
                child: ClipRRect(
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isFromMe ? 8 : 0),
                        topRight: Radius.circular(isFromMe ? 0 : 8),
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8)),
                    child: FittedBox(
                        child: Container(
                            constraints: BoxConstraints(
                              minWidth: 1,
                              minHeight: 1,
                            ),
                            /*decoration: BoxDecoration(
                                image: DecorationImage(
                                    fit: BoxFit.fitWidth,
                                    image: */
                            child: Image.network(_message.message))))) //))
            : Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                margin: EdgeInsets.only(top: 2),
                padding:
                    EdgeInsets.only(left: 16, right: 16, top: 6, bottom: 8),
                decoration: BoxDecoration(
                    color: isFromMe ? particle : coal,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isFromMe ? 8 : 0),
                      topRight: Radius.circular(isFromMe ? 0 : 8),
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    )),
                child: _messageText(
                    _message.message,
                    TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                        color: isFromMe ? coal : Colors.white))));
  }

  @override
  Widget build(BuildContext context) {
    DateTime date =
        DateTime.fromMillisecondsSinceEpoch(_message.unixtime * 1000);

    List<Widget> children = [];

    if (_message.from != _conversation.myNumber) {
      children.add(ContactCircle.withDiameter(
          _conversation.contacts, _conversation.crmContacts, 44));
      children.add(Expanded(
          child: Column(children: [
        Align(
            alignment: Alignment.centerLeft,
            child: Text(DateFormat.jm().format(date),
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: smoke))),
        _renderMessage()
      ])));
    } else {
      children.add(Expanded(
          child: Column(children: [
        Align(
            alignment: Alignment.centerRight,
            child: Text(DateFormat.jm().format(date),
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: smoke))),
        _renderMessage()
      ])));
    }

    return Container(
        decoration: BoxDecoration(color: Colors.white),
        margin: EdgeInsets.only(bottom: 18),
        padding: EdgeInsets.only(left: 16, right: 16),
        child: Row(children: children));
  }
}
