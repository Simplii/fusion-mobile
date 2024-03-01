import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:image_picker/image_picker.dart';

class ConversationVM with ChangeNotifier {
  late String conversationDepartmentId;
  SMSConversation conversation;
  final FusionConnection fusionConnection = FusionConnection.instance;

  List<SMSMessage> conversationMessages = [];
  bool loadingMessages = false;
  bool showSnackBar = false;
  DateTime? scheduledAt;
  List<XFile> mediaToSend = [];

  ConversationVM({required this.conversation}) {
    conversationDepartmentId = conversation.getDepartmentId(
      fusionConnection: fusionConnection,
    );
    lookupMessages();
  }

  void lookupMessages() {
    loadingMessages = true;
    notifyListeners();
    fusionConnection.messages.getMessages(
      conversation,
      100,
      0,
      (List<SMSMessage> messages, fromServer) {
        conversationMessages = messages;
        conversationMessages.sort((SMSMessage m1, SMSMessage m2) {
          return m1.unixtime > m2.unixtime ? -1 : 1;
        });
        loadingMessages = false;
        notifyListeners();
        print("MDBM callback ${messages} $fromServer");
      },
      conversationDepartmentId,
    );
  }

  void updateView() {
    //TODO:update conversationListView too
    notifyListeners();
  }

  void assignCoworker(Coworker selectedCoworker) {
    conversation.assigneeUid = selectedCoworker.uid;
    fusionConnection.conversations.storeRecord(conversation);
    fusionConnection.conversations.editConvoAssignment(
      coworkerUid: selectedCoworker.uid,
      convo: conversation,
    );
    notifyListeners();
  }

  Future<bool> renameConversation(String newName) async {
    bool nameUpdated = await fusionConnection.conversations.renameConvo(
      conversation.conversationId ?? 0,
      newName,
    );
    conversation.groupName = newName;
    notifyListeners();
    return nameUpdated;
  }

  void onDepartmentChange(String departmentId) async {
    SMSDepartment department =
        fusionConnection.smsDepartments.getDepartment(departmentId);
    if (department.numbers.isNotEmpty) {
      loadingMessages = true;
      conversationDepartmentId = departmentId;
      conversationMessages = [];
      String myNumber = department.numbers.first;
      conversation = await fusionConnection.messages.checkExistingConversation(
        departmentId,
        myNumber,
        [conversation.number],
        conversation.contacts,
      );
      lookupMessages();
      loadingMessages = false;
      notifyListeners();
    }
  }

  void onPhoneNumberChange(String phoneNumber) async {
    SMSDepartment? department =
        fusionConnection.smsDepartments.getDepartmentByPhoneNumber(phoneNumber);
    if (department != null && department.id != null) {
      loadingMessages = true;
      conversationDepartmentId = department.id!;
      conversationMessages = [];
      String myNumber = phoneNumber;
      conversation = await fusionConnection.messages.checkExistingConversation(
        department.id!,
        myNumber,
        [conversation.number],
        conversation.contacts,
      );
      lookupMessages();
      loadingMessages = false;
      notifyListeners();
    }
  }
}
