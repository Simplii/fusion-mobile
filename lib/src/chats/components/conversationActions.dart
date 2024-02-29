import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/chats/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/conversation.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/components/list_view_bottom_sheet.dart';
import 'package:fusion_mobile_revamped/src/contacts/contact_profile_view.dart';
import 'package:fusion_mobile_revamped/src/contacts/edit_contact_view.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';

class ConversationActions extends StatelessWidget {
  final SMSConversation conversation;
  final String conversationDepartmentId;
  final ConversationVM conversationVM;
  final ChatsVM? chatsVM;
  final List<SMSMessage> messages;
  const ConversationActions({
    required this.conversation,
    required this.conversationVM,
    required this.conversationDepartmentId,
    required this.messages,
    this.chatsVM,
    super.key,
  });

  String _sheetLabel() {
    String label = conversation.number.formatPhone();
    if (conversation.groupName.isNotEmpty) {
      label = conversation.groupName;
    } else if (conversation.filters != null) {
      label = "Broadcast - Query";
    } else if (conversation.isBroadcast) {
      label = "Broadcast - Batch";
    } else if (conversation.isGroup) {
      label = "Group Conversation";
    } else if (!conversation.isGroup &&
        conversation.contacts.isNotEmpty &&
        conversation.contacts[0].id.isNotEmpty) {
      label =
          "${conversation.contacts[0].firstName} ${conversation.contacts[0].lastName}";
    }
    return label;
  }

  List<List<String>> _bottomSheetOptions({
    required List<List<String>> unknownContact,
  }) {
    List<List<String>> options = [
      ["Shared Media", "sharedmedia"],
      ["Delete Conversation", "deleteconversation"],
    ];

    if (conversation.isGroup) {
      options.add(["Rename Conversation", "rename"]);
    }
    if (conversation.isGroup && !conversation.isBroadcast) {
      options.add(["Open Members List", "convoMembers"]);
      options.add(["Mark Unread", "markunread"]);
      if (conversationDepartmentId != DepartmentIds.FusionChats &&
          conversationDepartmentId != DepartmentIds.Personal) {
        options.add(["Assign Conversation", "assignConvo"]);
      }
      if (unknownContact.isNotEmpty) {
        options = [...options, ...unknownContact];
      }
    }
    if (!conversation.isGroup) {
      options.add(["Open Contact Profile", "contactprofile"]);
      if (conversationDepartmentId != DepartmentIds.FusionChats &&
          conversationDepartmentId != DepartmentIds.Personal) {
        options.add(["Assign Conversation", "assignConvo"]);
      }
      if (unknownContact.isNotEmpty) {
        options = [...options, ...unknownContact];
      }
    }
    return options;
  }

  _mediaGallery({SMSMessage? activeMessage}) {
    List<SMSMessage> galleryItems = messages
        .where((SMSMessage message) {
          return message.mime != null && message.mime!.contains("image") ||
              message.mime != null && message.mime!.contains("video");
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
            if (message.mime!.contains("image"))
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
                    : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
              ),
            ),
          ),
          backgroundDecoration: BoxDecoration(color: Colors.transparent),
          pageController: pageController,
          onPageChanged: (int page) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Contact> unknownContacts =
        conversation.contacts.where((contact) => contact.id == '').toList();
    List<List<String>> contactsToAdd = conversation.isBroadcast
        ? []
        : List.generate(
            unknownContacts.length,
            (index) => [
                  "Add ${unknownContacts[index].name} as a new contact",
                  "addContact-${index} "
                ],
            growable: false);
    //TODO: passdown softphone & fusionconnection
    Softphone? _softphone = Softphone.instance;
    FusionConnection _fusionConnection = FusionConnection.instance;

    return FusionDropdown(
      selectedNumber: "",
      onChange: (String chosen) {
        if (chosen == "contactprofile") {
          Future.delayed(
            Duration(milliseconds: 10),
            () {
              if (_softphone == null) return;
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (context) => ContactProfileView(
                  _fusionConnection,
                  _softphone,
                  conversation.contacts[0],
                  null,
                ),
              );
            },
          );
        } else if (chosen == "deleteconversation") {
          chatsVM?.deleteConvoFromActions(conversation: conversation);
          Navigator.pop(context, true);
        } else if (chosen.contains("addContact")) {
          int chosenUnknownContactIndex = int.parse(chosen.split('-').last);
          Future.delayed(Duration(milliseconds: 10), () {
            if (unknownContacts[chosenUnknownContactIndex] == null) return;
            showModalBottomSheet(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height - 50),
              context: context,
              backgroundColor: particle,
              isScrollControlled: true,
              builder: (context) => EditContactView(
                _fusionConnection,
                unknownContacts[chosenUnknownContactIndex],
                () => Navigator.pop(context, true),
                conversationVM.updateView,
              ),
            );
          });
        } else if (chosen == "markunread") {
          _fusionConnection.conversations.markUnread(
            conversation.message!.id,
            conversation,
            () => Navigator.pop(context),
          );
          chatsVM?.refreshView();
        } else if (chosen == "assignConvo") {
          Coworker emptyCoworker = Coworker.empty();
          emptyCoworker.uid = "Unassigned";
          emptyCoworker.firstName = "Unassigned";
          List<Coworker> coworkers = [emptyCoworker];
          SMSDepartment department =
              _fusionConnection.smsDepartments.getDepartment(
            conversationVM.conversationDepartmentId,
          );
          for (DepartmentUser departmentUser in department.users) {
            Coworker? coworker =
                _fusionConnection.coworkers.getCowworker(departmentUser.uid);
            if (coworker != null) {
              coworkers.add(coworker);
            }
          }
          Future.delayed(Duration(milliseconds: 10), () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Color.fromRGBO(0, 0, 0, 0),
              builder: (context) => ListViewBottomsheet(
                itemCount: coworkers.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      conversationVM.assignCoworker(coworkers[index]);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: lightDivider,
                            width: 1,
                          ),
                        ),
                      ),
                      padding: EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            foregroundImage:
                                coworkers[index].uid == 'Unassigned'
                                    ? AssetImage("assets/blank_avatar.png")
                                    : NetworkImage(coworkers[index].url)
                                        as ImageProvider,
                          ),
                          SizedBox(
                            width: 12,
                          ),
                          Wrap(
                            direction: Axis.vertical,
                            spacing: 4,
                            children: [
                              LimitedBox(
                                maxWidth:
                                    MediaQuery.of(context).size.width - 150,
                                child: Text(
                                  "${coworkers[index].firstName} ${coworkers[index].lastName}",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (coworkers[index].uid != "Unassigned")
                                Text(
                                  "Ext: ${coworkers[index].extension}",
                                  style: TextStyle(
                                    color: ash,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                            ],
                          ),
                          Spacer(),
                          if (conversation.assigneeUid != null &&
                              coworkers[index].uid.toLowerCase() ==
                                  conversation.assigneeUid!.toLowerCase())
                            Icon(
                              Icons.check,
                              color: Colors.white,
                            )
                        ],
                      ),
                    ),
                  );
                },
                label: "Select Coworker",
              ),
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
                    initialValue: _sheetLabel(),
                    onChanged: (value) {
                      setDialogState(() {
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
                        style: TextButton.styleFrom(foregroundColor: char),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("Cancel")),
                    TextButton(
                      onPressed: conversationName.isEmpty
                          ? null
                          : () async {
                              setDialogState(() {
                                renaming = true;
                              });
                              bool nameUpdated = await conversationVM
                                  .renameConversation(conversationName);
                              setDialogState(
                                () {
                                  renaming = false;
                                  if (!nameUpdated) {
                                    showError = true;
                                  } else {
                                    Navigator.of(context).pop();
                                    chatsVM?.refreshView();
                                  }
                                },
                              );
                            },
                      child: renaming
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(),
                            )
                          : Text("Rename",
                              style: conversationName.isEmpty
                                  ? null
                                  : TextStyle(color: crimsonDark)),
                    )
                  ],
                );
              },
            ),
          );
        } else {
          Future.delayed(Duration(milliseconds: 10), () {
            showModalBottomSheet(
                context: context,
                backgroundColor: translucentBlack(0.3),
                isScrollControlled: true,
                builder: (context) {
                  return _mediaGallery();
                });
          });
        }
      },
      value: "",
      options: _bottomSheetOptions(unknownContact: contactsToAdd),
      label: _sheetLabel(),
      button: Icon(
        Icons.more_vert,
        size: 32,
        color: smoke,
      ),
    );
  }
}
