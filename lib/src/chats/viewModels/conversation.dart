import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';

class ConversationVM with ChangeNotifier {
  late String conversationDepartmentId;
  final SMSConversation conversation;
  final FusionConnection fusionConnection = FusionConnection.instance;

  List<SMSMessage> conversationMessages = [];
  bool loadingMessages = false;

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
}
