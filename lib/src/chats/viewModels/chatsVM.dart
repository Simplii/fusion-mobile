import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatsVM extends ChangeNotifier {
  final FusionConnection fusionConnection;
  final Softphone softPhone;
  final SharedPreferences sharedPreferences;
  final int conversationsLimit = 100;
  late final StreamSubscription<RemoteMessage> notificationsStream;
  //mutable values
  String selectedDepartmentId = "-2";
  bool loading = false;
  int _offset = 0;
  List<SMSConversation> conversations = [];

  ChatsVM({
    required this.fusionConnection,
    required this.softPhone,
    required this.sharedPreferences,
  }) {
    selectedDepartmentId = sharedPreferences.getString("selectedGroupId") ??
        DepartmentIds.AllMessages;
    lookupMessages();
    notificationsStream =
        FirebaseMessaging.onMessage.listen(_onForegroundNotificationReceived);
  }

  void cancelNotificationsStream() {
    notificationsStream.cancel();
  }

  void _onForegroundNotificationReceived(RemoteMessage remoteMessage) {
    if (remoteMessage.notification != null) {
      print("MDBM remoteMessage ${remoteMessage.notification}");
    }
  }

  void refreshView() {
    notifyListeners();
  }

  String selectedDepartmentName() {
    SMSDepartment? dep =
        fusionConnection.smsDepartments.getDepartment(selectedDepartmentId);
    return dep?.groupName ?? "All Messages";
  }

  List<List<String>> groupOptions() {
    List<SMSDepartment> departments =
        fusionConnection.smsDepartments.allDepartments();
    List<List<String>> options = [];

    departments.sort((a, b) => a.groupName == "All Messages"
        ? -1
        : (a.groupName != "All Messages" && int.parse(a.id!) < int.parse(b.id!))
            ? -1
            : 1);
    for (SMSDepartment d in departments) {
      options.add([
        d.groupName ?? "",
        d.id ?? "",
        d.unreadCount.toString(),
        d.id ?? "",
        d.protocol ?? ""
      ]);
    }
    return options;
  }

  void onGroupChange(String newGroupId) {
    sharedPreferences.setString('selectedGroupId', newGroupId);
    selectedDepartmentId = newGroupId;
    lookupMessages();
    notifyListeners();
  }

  lookupMessages() async {
    loading = true;
    notifyListeners();

    await fusionConnection.conversations.getConversations(
      selectedDepartmentId,
      conversationsLimit,
      _offset,
      (
        List<SMSConversation> convos,
        bool fromServer,
        String departmentId,
        String? errorMessage,
      ) {
        if (_offset == 0) {
          conversations = convos;
        } else {
          Map<String?, SMSConversation> allconvos = {};
          for (SMSConversation s in conversations) allconvos[s.getId()] = s;
          for (SMSConversation s in convos) allconvos[s.getId()] = s;
          conversations = allconvos.values.toList().cast<SMSConversation>();
        }
        conversations.sort((SMSConversation a, SMSConversation b) {
          return DateTime.parse(a.lastContactTime)
                  .isAfter(DateTime.parse(b.lastContactTime))
              ? -1
              : 1;
        });
      },
    );
    loading = false;
    print("MDBM conversations offset $_offset");
    notifyListeners();
  }

  void deleteConversation({
    required int conversationIndex,
  }) {
    fusionConnection.conversations.deleteConversation(
      conversations[conversationIndex],
      selectedDepartmentId,
    );
    conversations.removeAt(conversationIndex);
    notifyListeners();
  }

  void deleteConvoFromActions({
    required SMSConversation conversation,
  }) {
    print("MDBM delete ${conversations.length}");
    fusionConnection.conversations.deleteConversation(
      conversation,
      selectedDepartmentId,
    );
    SMSConversation? convo = conversations
        .where(
            (element) => element.conversationId == conversation.conversationId)
        .firstOrNull;
    if (convo != null) {
      conversations.removeAt(conversations.indexOf(convo));
      print("MDBM deleted ${conversations.length}");
    }

    notifyListeners();
  }

  SMSDepartment getConversationDepartment({required String convoMyNumber}) {
    return fusionConnection.smsDepartments
            .getDepartmentByPhoneNumber(convoMyNumber) ??
        fusionConnection.smsDepartments.getDepartment("-2");
  }

  Future<List<SMSConversation>> loadMoreConvos() async {
    List<SMSConversation> newConvos = [];
    await fusionConnection.conversations.getConversations(
      selectedDepartmentId,
      conversationsLimit,
      _offset,
      (
        convs,
        fromServer,
        departmentId,
        errorMessage,
      ) =>
          newConvos = convs,
    );
    print("MDBM new ${newConvos.length}");
    return newConvos;
  }
}
