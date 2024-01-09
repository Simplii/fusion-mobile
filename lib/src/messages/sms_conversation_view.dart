import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/components/date_time_picker.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/components/list_view_bottom_sheet.dart';
import 'package:fusion_mobile_revamped/src/components/popup_menu.dart';
import 'package:fusion_mobile_revamped/src/contacts/contact_profile_view.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/models/quick_response.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../backend/fusion_connection.dart';
import '../contacts/edit_contact_view.dart';
import '../styles.dart';
import '../utils.dart';

class SMSConversationView extends StatefulWidget {
  final FusionConnection fusionConnection;
  final SMSConversation smsConversation;
  final Softphone softphone;
  final Function(SMSConversation, SMSMessage) deleteConvo;
  final Function setOnMessagePosted;
  final Function(SMSConversation) changeConvo;
  SMSConversationView(
    {this.fusionConnection, 
    this.softphone, 
    this.smsConversation, 
    this.deleteConvo,
    this.setOnMessagePosted,
    this.changeConvo,
     Key key}
  ) : super(key: key);

  // static openConversation(
  //     BuildContext context,
  //     FusionConnection fusionConnection,
  //     List<Contact> contacts,
  //     List<CrmContact> crmContacts,
  //     Softphone softphone,
  //     String phoneNumber,
  //     Function _deleteConvo,
  //     Function setOnMessagePosted) {
  //   showModalBottomSheet(
  //       context: context,
  //       backgroundColor: Colors.transparent,
  //       isScrollControlled: true,
  //       builder: (context) => SMSConversationView(
  //           fusionConnection,
  //           softphone,
  //           SMSConversation.build(
  //               contacts: contacts,
  //               crmContacts: crmContacts,
  //               isGroup: false,
  //               myNumber: fusionConnection.smsDepartments
  //                   .getDepartment("-2")
  //                   .numbers[0],
  //               number: phoneNumber),
  //           _deleteConvo,
  //           setOnMessagePosted,
  //           changeConvo;

  //           ));
  // }

  @override
  State<StatefulWidget> createState() => _SMSConversationViewState();
}

class _SMSConversationViewState extends State<SMSConversationView> {
  FusionConnection get _fusionConnection => widget.fusionConnection;

  Softphone get _softphone => widget.softphone;
  StreamSubscription<ConnectivityResult> connectivitySubscription;
  SMSConversation get _conversation => widget.smsConversation;
  TextEditingController _messageInputController = TextEditingController();
  bool _loaded = false;
  List<XFile> _mediaToSend = [];
  List<SMSMessage> _messages = [];
  List<String> _savedImgPaths = [];
  String _selectedGroupId = "";
  Timer _debounceMessageInput;
  int textLength = 0;
  Function(SMSConversation, SMSMessage) get _deleteConvo => widget.deleteConvo;
  Function get _setOnMessagePosted => widget.setOnMessagePosted;
  bool showSnackBar = false;
  String snackBarText = "";
  bool isSavedMessage = false;
  bool loading = false;
  List<QuickResponse> quickResponses = [];
  DateTime secheduleIsSet;

  Function get _changeConvo => widget.changeConvo;
  bool disableDepartmentSelection = false;
  initState() {
    super.initState();
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      String savedMessage =
          prefs.getString(_conversation.hash + "_savedMessage");
      _messageInputController.text = savedMessage;
      isSavedMessage = savedMessage != null && savedMessage.length > 0;

      final String path = getApplicationDocumentsDirectory().toString();
      List<String> savedImgs =
          prefs.getStringList(_conversation.hash + "_savedImages");
      if (savedImgs != null) {
        savedImgs.map((e) => {_mediaToSend.add(XFile("$path/$e"))});
      }
    });

    if (_fusionConnection.smsDepartments.lookupRecord(DepartmentIds.AllMessages) != null) {
      _loaded = true;
    }
    _fusionConnection.smsDepartments.getDepartments((List<SMSDepartment> list) {
      if (!mounted) return;
      this.setState(() {
        _loaded = true;
      });
    });

    SMSDepartment department = _fusionConnection.smsDepartments
        .getDepartmentByPhoneNumber(_conversation.myNumber);
    this.setState(() {
      _selectedGroupId = department?.id ?? DepartmentIds.Personal;
    });

    _updateQuickMessages(selectedDept: _selectedGroupId);
    disableDepartmentSelection = _selectedGroupId == DepartmentIds.FusionChats;
    connectivitySubscription =
      _fusionConnection.connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    setState(() {
      _fusionConnection.connectivityResult = result;
    });
  }

  @override
  void dispose() {
    _debounceMessageInput?.cancel();
    connectivitySubscription?.cancel();
    super.dispose();
  }

  _updateQuickMessages({String selectedDept = ""}){
    _fusionConnection.quickResponses.getQuickResponses(
      selectedDept == DepartmentIds.AllMessages ? DepartmentIds.Personal : selectedDept,
      (List<QuickResponse> data){
        setState(() {
          quickResponses = data;
        }); 
      }
    );
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
          return message.mime != null && message.mime.contains("image") || message.mime != null &&
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
    Coworker _coworker;
    if(_conversation.number.contains("@")){
      _fusionConnection.coworkers.getRecord(_conversation.number, (coworker) => _coworker = coworker);
    }

    List<Widget> singleMessageHeader = [
      _coworker != null 
        ? ContactCircle.withCoworkerAndDiameter([], [], _coworker, 60)
        : ContactCircle(_conversation.contacts, _conversation.crmContacts),
      Expanded(child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_conversation.contactName(coworker: _coworker), style: headerTextStyle)),
          Align(
          alignment: Alignment.centerLeft,
          child: Text(_conversation.number.formatPhone(),
              style: subHeaderTextStyle))]
        )
      ),
    ];
    
    Widget groupMessageHeader = 
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8,7,8,3),
          child: LimitedBox(
          maxHeight: 50,
          maxWidth: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _conversation.contacts.length,
            shrinkWrap: true,
            itemBuilder: (context, index) {
              String imageUrl = _conversation.contacts[index].pictures.length > 0 
              ? _conversation.contacts[index].pictures.last['url'] 
              : avatarUrl(_conversation.contacts[index].firstName, 
                _conversation.contacts[index].lastName);
              ImageProvider image = _conversation.contacts[index].profileImage != null
                ? MemoryImage(_conversation.contacts[index].profileImage)
                : NetworkImage(imageUrl);

              return Align(
                widthFactor: 0.6,
                child: ClipRRect(
                  borderRadius:BorderRadius.circular(60),
                  child: Container(
                      height:50,
                      width: 50,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius:BorderRadius.circular(60),
                          border: Border.all(color: particle, width: 2),
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            image: image
                          )
                        ),
                      )
                  ),
                ),
              );
            },
          ),
      ),
        )
    );
    List<Contact> unknowContacts = 
      _conversation.contacts.where((contact) => contact.id == '').toList();
    List<List<String>> contactsToAdd = _conversation.isBroadcast 
      ? [] 
      : List.generate(unknowContacts.length, 
        (index) => ["Add ${unknowContacts[index].name} as a new contact", 
        "addContact-${index} "], growable: false);

    return Column(children: [
      Center(
          child: Container(
              decoration: BoxDecoration(
                  color: halfSmoke,
                  borderRadius: BorderRadius.all(Radius.circular(3))),
              width: 36,
              height: 5)),
      Row(children: [
        if(_conversation.isGroup)
          groupMessageHeader,
        if(!_conversation.isGroup)
          ...singleMessageHeader,
        if(!_conversation.isGroup)
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
              widget.softphone.makeCall(_conversation.number);
            }),
        FusionDropdown(
            selectedNumber: "",
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
                          _conversation.contacts[0],null));
                });
              } else if (chosen == "deleteconversation") {
                if(_deleteConvo != null){
                  _deleteConvo(_conversation,null);
                  _fusionConnection.conversations.deleteConversation(
                      _conversation,
                      _selectedGroupId);
                }
                Navigator.pop(context, true);
              } else if (chosen.contains("addContact")) {
                int chosenUnknownContactIndex = int.parse(chosen.split('-').last);
                Future.delayed(Duration(milliseconds: 10), () {
                  if(unknowContacts[chosenUnknownContactIndex] == null)return;
                  showModalBottomSheet(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height - 50),
                    context: context,
                    backgroundColor: particle,
                    isScrollControlled: true,
                    builder: (context) => EditContactView(
                      _fusionConnection, 
                      unknowContacts[chosenUnknownContactIndex], 
                      () => Navigator.pop(context, true),
                      () => setState(() { 
                        _setOnMessagePosted(null); 
                      })
                    ));
                });
              } else if (chosen == "markunread"){
                _fusionConnection.conversations.markUnread(_conversation.message.id,_conversation, 
                  () => Navigator.pop(this.context)
                );
              } 
              else if (chosen == "assignConvo") {
                print("MDBM assign");
                Coworker emptyCoworker = Coworker.empty();
                emptyCoworker.uid = "Unassigned";
                emptyCoworker.firstName = "Unassigned"; 
                List<Coworker> coworkers = [
                  emptyCoworker
                ];
                SMSDepartment department = _fusionConnection.smsDepartments.getDepartment(_selectedGroupId);
                for (DepartmentUser departmentUser in department.users) {
                  if(_fusionConnection.coworkers.getCowworker(departmentUser.uid) != null) {
                    coworkers.add(_fusionConnection.coworkers.getCowworker(departmentUser.uid));
                  }
                }
                Future.delayed(Duration(milliseconds: 10), (){
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Color.fromRGBO(0, 0, 0, 0),
                    builder: (context) => ListViewBottomsheet(
                      itemCount: coworkers.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            _assignCoworker(coworkers[index]); 
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: lightDivider,
                                  width: 1
                                )
                              )
                            ),
                            padding: EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  foregroundImage: coworkers[index].uid == 'Unassigned' 
                                    ? AssetImage("assets/blank_avatar.png")
                                    : NetworkImage(coworkers[index].url),
                                ),
                                SizedBox(width: 12,),
                                Wrap(
                                  direction: Axis.vertical,
                                  spacing: 4,
                                  children: [
                                    LimitedBox(
                                      maxWidth: MediaQuery.of(context).size.width - 150,
                                      child: Text(
                                        "${coworkers[index].firstName} ${coworkers[index].lastName}",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                    ),
                                    if(coworkers[index].uid != "Unassigned")
                                    Text(
                                      "Ext: ${coworkers[index].extension}",
                                      style: TextStyle(
                                        color: ash,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold
                                      ),
                                    )
                                  ],
                                ),
                                Spacer(),
                                if(coworkers[index].uid.toLowerCase() == _conversation.assigneeUid.toLowerCase())
                                  Icon(Icons.check, color: Colors.white,)
                              ],
                            ),
                          ),
                        );
                      },
                      label: "Select Coworker",
                    )
                  );
                  
                });
              } else if (chosen == "rename") {
                String conversationName = "";
                bool renaming = false;
                bool showError = false;
                showDialog(
                  context: context, 
                  builder: (context) => StatefulBuilder(
                    builder: (context, StateSetter setDialogState) {
                      return AlertDialog(
                        title: const Text('Rename Conversation'),
                        content: TextFormField(
                          initialValue: convoLabel(),
                          onChanged: (value) {
                            setDialogState((){
                              conversationName = value;
                            });
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            errorText: showError ? "Unable to rename" : null, 
                          ),
                        ),
                        actions: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: char
                            ),
                            onPressed: ()=> Navigator.of(context).pop(), 
                            child: Text("Cancel")
                          ),
                          TextButton(
                            onPressed: conversationName.isEmpty 
                              ? null 
                              : () async {
                                setDialogState((){
                                  renaming = true;
                                });
                                bool nameUpdated = await _fusionConnection.conversations.renameConvo(
                                  _conversation.conversationId, conversationName
                                );
                                setState(() {
                                  _conversation.groupName = conversationName;
                                });
                                setDialogState((){
                                  renaming = false;
                                  if (!nameUpdated) {
                                    showError = true;
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                });
                              }, 
                            child: renaming 
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) 
                            : Text(
                              "Rename", 
                              style: conversationName.isEmpty 
                                ? null
                                : TextStyle(color: crimsonDark))
                          )
                        ],
                      );
                    }
                  )
                );
              } else {
                Future.delayed(Duration(milliseconds: 10), () {
                  _openMedia(null);
                });
              }
            },
            value: "",
            options: bottomsheetOptions(unknownContact: contactsToAdd),
            label: convoLabel(),
            button: Icon(Icons.more_vert, size: 32,color: smoke,))
      ]),
      Row(children: [horizontalLine(16)]),
      Row(children: [
        Expanded(child: Container()),
        Align(alignment: Alignment.centerRight, child: _departmentName()),
      ])
    ]);
  }

  void _assignCoworker(Coworker selectedCoworker) {
    setState(() {
      _conversation.assigneeUid = selectedCoworker.uid;
    });
    _fusionConnection.conversations.editConvoAssignment(
      coworkerUid: selectedCoworker.uid, convo: _conversation
    );
  }

  List<List<String>> bottomsheetOptions ({@required List<List<String>> unknownContact}) {
    List<List<String>> options = [
      ["Shared Media", "sharedmedia"],
      ["Delete Conversation", "deleteconversation"],
    ];

    if (_conversation.isGroup) {
      options.add(["Rename Conversation", "rename"]);
    }
    if (_conversation.isGroup && !_conversation.isBroadcast) {
      options.add(["Open Members List", "convoMembers"]);
      options.add(["Mark Unread", "markunread"]);
      if(_selectedGroupId != DepartmentIds.FusionChats &&
        _selectedGroupId != DepartmentIds.Personal){
          options.add(["Assign Conversation", "assignConvo"]);
      }
      if (unknownContact.isNotEmpty) {
        options = [...options, ...unknownContact];
      }
    }
    if (!_conversation.isGroup) {
      options.add(["Open Contact Profile", "contactprofile"]);
      if(_selectedGroupId != DepartmentIds.FusionChats &&
        _selectedGroupId != DepartmentIds.Personal){
          options.add(["Assign Conversation", "assignConvo"]);
      }
      if (unknownContact.isNotEmpty) {
        options = [...options, ...unknownContact];
      }
    }
    return options;
  }

  String convoLabel () {
    String label = _conversation.number.formatPhone();
    if (_conversation.groupName != null && _conversation.groupName.isNotEmpty) {
      label = _conversation.groupName;
    } 
    else if (_conversation.filters != null) {
      label = "Broadcast - Query";
    }
    else if (_conversation.isBroadcast) {
      label = "Broadcast - Batch";
    }
    else if (_conversation.isGroup) {
      label = "Group Conversation";
    }
    else if (!_conversation.isGroup && 
      _conversation.contacts.isNotEmpty && 
      _conversation.contacts[0].id.isNotEmpty) {
        label = "${_conversation.contacts[0].firstName} ${_conversation.contacts[0].lastName}";
    }
    return label;
  }

  _departmentName() {
    List departments = _fusionConnection.smsDepartments.allDepartments();

    List<List<String>> options = [];

    for (SMSDepartment department in departments) {
      if (department.id == DepartmentIds.AllMessages || department.id == DepartmentIds.FusionChats) {
        continue;
      }
      options.add([department.groupName, department.id]);
    }

    return Container(
        decoration: dropdownDecoration,
        padding: EdgeInsets.only(top: 0, bottom: 0, right: 0, left: 8),
        height: 36,
        child: FusionDropdown(
          disabled: disableDepartmentSelection,
            departments: departments,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            value: _selectedGroupId,
            selectedNumber: _conversation.myNumber,
            options: options,
            onChange: _onDepartmentChange,
            onNumberTap: _onNumberSelect,
            label: "All Departments"));
  }

  _onDepartmentChange(String newDeptId) {
    _updateQuickMessages(selectedDept: newDeptId);
    SMSDepartment dept =
        _fusionConnection.smsDepartments.getDepartment(newDeptId);
    setState(() {
      _conversation.myNumber = dept.numbers[0];
      _selectedGroupId = newDeptId;
      _conversation.conversationId = null;
    });
  }
  
  _onNumberSelect(String newNumber) {
    SMSDepartment dept =
        _fusionConnection.smsDepartments.getDepartmentByPhoneNumber(newNumber);
    _updateQuickMessages(selectedDept: dept.id);
    setState(() {
      _conversation.myNumber = newNumber;
      _selectedGroupId = dept.id;
      _conversation.conversationId = null;
    });
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

  _openQuickResponses(){
    List<String> messages = quickResponses.map((qr) => qr.message,).toList();
     showModalBottomSheet(
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7),
      context: context,
      isScrollControlled: true,
      builder: (context) => PopupMenu(
        label: "Quick Responses",
        bottomChild: messages.length > 0 
        ? Container(
            height: MediaQuery.of(context).size.height * 0.3,
            child: ListView.separated(
              itemBuilder: (BuildContext context, int index){
                return GestureDetector(
                  onTap: (){
                    setState(() {
                      _messageInputController.text = messages[index];
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: EdgeInsets.only(top: index == 0 ? 8 : 0),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(messages[index], style:TextStyle(
                        fontSize: 16,
                        color: Colors.white
                      ),textAlign: TextAlign.center,),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => Divider(
                color: lightDivider,
                thickness: 1.0,
              ),
              itemCount: messages.length
            ),
          )
        : Container(
          height: 100,
          child: Center(
            child: Text("no quick responses found".toTitleCase(), 
              style:TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.5,
              ),textAlign: TextAlign.center)),
        )
      ));
  }

  _openMessageScheduling(){
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
          onComplete: (DateTime selectedDateTime){
            setState(() {
              if(selectedDateTime != null) secheduleIsSet = selectedDateTime;
            });
          }
        ),
      )
    );
  }

  _sendMessageInput() {
    DateFormat dateFormatter = DateFormat('MMM d,');
    Coworker assignedTo = _conversation.assigneeUid != null 
      ? _fusionConnection.coworkers.getCowworker(_conversation.assigneeUid.toLowerCase())
      : null;
    return Container(
        decoration: BoxDecoration(color: particle),
        padding: EdgeInsets.only(
            top: secheduleIsSet != null ? 0 : 12,
            left: 8,
            bottom: (iphoneIsLarge() &&
                    MediaQuery.of(context).viewInsets.bottom == 0)
                ? 32
                : 12,
            right: 8),
        child: Column(
          children: [
            if(assignedTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(
                      "Assigned to: ${assignedTo.firstName} ${assignedTo.lastName}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: assignedTo.uid.toLowerCase() != _fusionConnection.getUid().toString().toLowerCase() 
                          ? crimsonDark
                          : coal
                      ),
                    ),
                  ],
                ),
              ),
            if(secheduleIsSet != null)
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
                    child: Text("Will be sent: " + 
                      dateFormatter.add_jm().format(secheduleIsSet).toString(),
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    )
                  ),
                  IconButton(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    constraints: BoxConstraints(),
                    onPressed: (){
                      setState(() {
                        secheduleIsSet = null;
                      });
                    }, 
                    icon: Icon(Icons.remove_circle_outline_rounded, color: Colors.red,)
                  )
                ],
              ),
            ),
            Row(
            children: [
              FusionDropdown(
                selectedNumber: "",
                onChange: (String value) {
                  if(value == "schedule"){
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
                    child: Icon(Icons.add, size: 28,color: smoke,))),
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
                    textAlignVertical: TextAlignVertical.center,
                    textCapitalization: TextCapitalization.sentences,
                    controller: _messageInputController,
                    maxLines: 10,
                    minLines: 1,
                    onChanged: (String changedTo) {
                      if (_messageInputController.text.length - textLength > 1 
                          && !isSavedMessage
                          && _messageInputController.text.contains("https://fusioncom.co/media")){
                        SharedPreferences.getInstance().then((SharedPreferences prefs) {
                          String imageUri = prefs.getString("copiedImagePath");
                          if(imageUri.length == 0){
                            this.setState(() {
                              _saveLocalState(changedTo);
                            });
                          }else {
                            setState(() {
                              _mediaToSend.add(XFile('$imageUri'));
                              _messageInputController.text = '';
                              Clipboard.setData(ClipboardData(text: ''));
                            });
                          }
                        },);
                      }else {
                        setState(() {
                          _saveLocalState(changedTo);
                        });
                      }
                      textLength = _messageInputController.text.length;
                    },
                    decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(Icons.chat_bubble_outline_outlined),
                       onPressed: _openQuickResponses),
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
                        child: CircularProgressIndicator(color: Colors.white,))
                    ) 
                  : Image.asset(
                      _hasEnteredMessage()
                          ? "assets/icons/send_active.png"
                          : "assets/icons/send.png",
                      height: 40,
                      width: 40),
                  onPressed: loading ? null : _sendMessage,
                ))
          ])],
        ));
  }

  _hasEnteredMessage() {
    return _mediaToSend.length > 0 ||
        _messageInputController.value.text.trim().length > 0;
  }
  
  void _largeMMS(){
    showSnackBar = true;
    snackBarText = "Sorry you don't have Large MMS turned on";
    Future.delayed(const Duration(seconds: 3), () {
      setState(() {
        showSnackBar = false;
      });
    });
  }

  _sendMessage() async{
    setState(() {
      disableDepartmentSelection = true;
      loading = true;
    });
    await _fusionConnection.checkInternetConnection();
    setState(() {
      loading = false;
      if (_messageInputController.value.text.trim().length > 0) {
        if(!_fusionConnection.internetAvailable){
          if(_conversation.message != null){
            _fusionConnection.messages.offlineMessage(
              _messageInputController.value.text, 
              _conversation, 
              _selectedGroupId, 
              null, 
              _setOnMessagePosted, 
              ()=>null,
              secheduleIsSet ?? secheduleIsSet);
          } else {
            toast("unable to connect to the internet".toUpperCase());
          }
          _messageInputController.text = "";
          
        } else {
          _fusionConnection.messages
            .sendMessage(
              _messageInputController.value.text, 
              _conversation, 
              _selectedGroupId, 
              null,
              (){
                if(_setOnMessagePosted != null)_setOnMessagePosted(_conversation.getId());
                if(!mounted)return;
                setState(() {
                  secheduleIsSet = null;
                });
                Future.delayed(Duration(seconds: 4), (){
                  if(mounted){
                    setState(() {
                      disableDepartmentSelection = false;
                    });
                  }
                });
              }, 
              ()=> null,
              secheduleIsSet ?? secheduleIsSet 
            );
          _messageInputController.text = "";
        }
      }
      if (_mediaToSend.length > 0) {
        for (XFile file in _mediaToSend) {
          _fusionConnection.messages.sendMessage(
            '', 
            _conversation,
            _selectedGroupId,
            file,
            _setOnMessagePosted,
            _largeMMS,
            secheduleIsSet ?? secheduleIsSet );
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
                                        }, _openMedia,_deleteConvo, _selectedGroupId,_setOnMessagePosted,_changeConvo)
                                      : Container())
                            ]))),
                  ]))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.fastOutSlowIn,
              height: showSnackBar ? 40 : 0,
              child: Row(
                children: [Expanded(
                  child: Container( 
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(left: 10),
                    color: coal,
                    child: Text(snackBarText,
                      style: TextStyle(color: Colors.white ,fontWeight: FontWeight.w600),)
                  ),
                )],
              ),
            ),
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
  final Function(SMSConversation, SMSMessage) _deleteConvo;
  final Function setOnMessagePosted;
  final Function(SMSConversation) changeConvo;
  String _selectedGroupId;
  ConvoMessagesList(this._fusionConnection, this._conversation,
      this._onPulledMessages, this._openMedia, this._deleteConvo, this._selectedGroupId, 
      this.setOnMessagePosted, this.changeConvo, {Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ConvoMessagesListState();
}

class _ConvoMessagesListState extends State<ConvoMessagesList> {
  SMSConversation get _conversation => widget._conversation;

  FusionConnection get _fusionConnection => widget._fusionConnection;

  Function(SMSMessage) get _openMedia => widget._openMedia;
  Function(SMSConversation, SMSMessage) get _deleteMessage => widget._deleteConvo;
  Function get _setOnMessagePosted => widget.setOnMessagePosted;
  Function(SMSConversation) get _changeConvo => widget.changeConvo;
  int lookupState = 0; // 0 - not looking up; 1 - looking up; 2 - got results
  List<SMSMessage> _messages = [];
  String _subscriptionKey;
  String get _selectedGroupId => widget._selectedGroupId;
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
    },_selectedGroupId);
  }

  Future<SMSConversation> _departmentSwitch () async {
    SMSConversation convo = await _fusionConnection.messages.checkExistingConversation(
          _selectedGroupId, _conversation.myNumber, [_conversation.number], []);
    return convo;
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
          thisTime.difference(lastDate).inHours.abs() > TimeOfDay.now().hour) {
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
      },_deleteMessage,_messages,_selectedGroupId,_setOnMessagePosted));
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
        if(_lookedupNumber != "" && _lookedupMyNumber != ""){
          _departmentSwitch().then((SMSConversation value){
            if(value.conversationId != null){
              _lookedupNumber = value.number;
              _lookedupMyNumber = value.myNumber;
              if(mounted){
                _changeConvo(value);
                _lookupMessages();
              }
            } 
          });
        }
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
  final Function(SMSConversation, SMSMessage) _deleteMessage;
  final Function setOnMessagePosted;
  List<SMSMessage> _messages;
  String _selectedGroupId;
  SMSMessageView(this._fusionConnection, this._message, this._conversation,
      this._openMedia, this._deleteMessage, this._messages, this._selectedGroupId,
      this.setOnMessagePosted, {Key key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _SMSMessageViewState();
}

class _SMSMessageViewState extends State<SMSMessageView> {
  FusionConnection get _fusionConnection => widget._fusionConnection;

  SMSConversation get _conversation => widget._conversation;

  SMSMessage get _message => widget._message;
  final _searchInputController = TextEditingController();

  final GlobalKey<TooltipState> tooltipkey = GlobalKey<TooltipState>();
  List<SMSMessage> get _messages => widget._messages;
  String get _selectedGroupId => widget._selectedGroupId;
  Function get _setOnMessagePosted => widget.setOnMessagePosted;
  _openMedia() {
    widget._openMedia(_message);
  }

  _deleteMessage(SMSMessage message){
    if(widget._deleteMessage == null) return;
    if(_messages.length == 1)
      widget._deleteMessage(_conversation,null);
    else if(_messages.reversed.last.id == message.id)
      widget._deleteMessage(_conversation,_messages.reversed.elementAt(_messages.length - 2));
    
    _messages.removeWhere((msg) => msg.id == message.id);
    _conversation.message = _messages.reversed.last;
    _fusionConnection.conversations.storeRecord(_conversation);
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
                onLongPress: () async {
                  await Clipboard.setData(ClipboardData(text: _message.message));
                  Clipboard.getData(Clipboard.kTextPlain)
                    .then((value){
                      if(value.text != ''){
                        tooltipkey.currentState?.ensureTooltipVisible();
                        urlToXFile(Uri.parse(value.text)).then((value) {
                          SharedPreferences.getInstance().then((SharedPreferences prefs) {
                            prefs.setString("copiedImagePath", value.path);
                          });
                        },);
                      }
                    });
                },
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
                            child: Tooltip(
                              message:'Copied',
                              key: tooltipkey,
                              triggerMode: TooltipTriggerMode.manual,
                              child: Image.network(_message.message),
                            )
                          )
                        )
                      )) //))
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

  Future<void> _tryResendFailedMessage(SMSMessage message) async {
    Navigator.pop(context);
    await _fusionConnection.checkInternetConnection();
    if(!_fusionConnection.internetAvailable){
      toast("unable to connect to the internet".toUpperCase());
    } else {
       await _fusionConnection.messages.resendFailedMessage(message);
       setState(() { 
        _messages.removeWhere((msg) => msg.id == message.id);
       });
     
      _fusionConnection.messages.sendMessage(
        message.message, 
        _conversation, 
        _selectedGroupId, 
        null,
        _setOnMessagePosted, 
        ()=> null,
        null
      );
    }

  }

  _openFailedMessageDialog(SMSMessage message){
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => PopupMenu(
        customLabel: Text('Your message was not sent, Tap "Try Again" to send this message',
          style: TextStyle(
            color: smoke,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            height: 1.5),
          textAlign: TextAlign.center,),
        bottomChild: Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: ()=>_tryResendFailedMessage(message),
                child: Text("Try Again", style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),),
              ),
            ),
          ],
        ),
      )
    );
  }

  _openScheduledMessage(SMSMessage message ){
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) { 
        DateTime date = DateTime.parse(message.scheduledAt).toLocal();
        DateFormat dateFormatter = DateFormat('MMM d,');
        return PopupMenu(
        label: "Scheduled Message",
        bottomChild: 
        Container(
          height: 150,
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Message will be sent on " + 
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
                  )
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: (){
                    setState(() {  
                      _messages.removeWhere((msg) => msg.id == message.id);
                      _fusionConnection.messages.deleteMessage(this._message.id,_selectedGroupId);
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel Message", style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                  ),),
                ),
              ),
            ],
          ),
        ),
      );}
    ); 
  }
  @override
  Widget build(BuildContext context) {
    DateTime date =
        DateTime.fromMillisecondsSinceEpoch(_message.unixtime * 1000);
    List<Widget> children = [];
    bool scheduledMessage = _message.scheduledAt != null 
      ? DateTime.parse(_message.scheduledAt).toLocal().isAfter(DateTime.now()) 
      : false;

    if (_message.from != _conversation.myNumber) {
      List<Contact> matchedContact;
      _conversation.contacts.forEach((element){
        Contact c = element;
        bool match = false;
        for (var numberObj in c.phoneNumbers) {
          if(_message.from == numberObj['number']){
            match = true;
            break;
          }
        }
        if(match){
          matchedContact = [element];
        }
      });
      children.add(ContactCircle.withDiameter(
          matchedContact ?? _conversation.contacts, _conversation.crmContacts, 44));
      children.add(Expanded(
          child: Column(children: [
        Align(
            alignment: Alignment.centerLeft,
            child: Text(matchedContact != null
              ? "${matchedContact[0].name.toTitleCase()} ${mDash} ${DateFormat.jm().format(date)}" 
              : "${_message.from.formatPhone()} ${mDash} ${DateFormat.jm().format(date)}",
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: smoke))),
        _renderMessage()
      ])));
    } else {

      Contact myContact = null;
      if(_message.user != null){
        myContact = _fusionConnection.coworkers.lookupCoworker(_message.user.split('@')[0] + 
          "@" + _fusionConnection.getDomain())?.toContact();
      }

      
      children.add(Expanded(
          child: Column(children: [
        Align(
           alignment: Alignment.bottomRight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _message.messageStatus == 'delivered' 
                ? Icon (Icons.check,size: 10, color:smoke)
                : (_message.messageStatus == 'failed' || _message.messageStatus == 'offline')
                  ? Icon(Icons.clear,size: 10, color: smoke,)
                  : Container(),
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 90
                ),
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(myContact?.name ?? "", style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800, color: smoke), 
                          textWidthBasis: TextWidthBasis.longestLine, 
                          overflow: TextOverflow.ellipsis, ),
              ),
              Text(DateFormat.jm().format(date),
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: smoke)),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 90
                ),
              child: _renderMessage() ,
            ),
            if(_message.messageStatus =="offline")
              IconButton(
                padding: EdgeInsets.only(left: 5),
                constraints: BoxConstraints(),
                onPressed: ()=>_openFailedMessageDialog(_message), 
                icon: Icon(Icons.error_outline,color: Colors.red)),
            if(scheduledMessage)
              IconButton(
                padding: EdgeInsets.only(left: 5),
                constraints: BoxConstraints(),
                onPressed: ()=>_openScheduledMessage(_message), 
                icon: Icon(Icons.schedule,color: smoke)),
          ],
        )
      ])));
    }

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _fusionConnection.messages.deleteMessage(this._message.id,_selectedGroupId);
        _deleteMessage(this._message);
        if(this._messages.length == 0){
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
                  child: const Text("DELETE")
                ),
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
          decoration: BoxDecoration(color: Colors.white),
          margin: EdgeInsets.only(bottom: 18),
          padding: EdgeInsets.only(left: 16, right: 16),
          child: Row(children: children)),
    );
  }
}
