import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatsVM extends ChangeNotifier {
  final String DebugTag = "MDBM ChatsVM";
  final FusionConnection fusionConnection;
  final Softphone softPhone;
  final SharedPreferences sharedPreferences;
  final int conversationsLimit = 50;
  final Debounce debounce = Debounce(Duration(milliseconds: 700));

  late final StreamSubscription<RemoteMessage> notificationsStream;

  //mutable values
  String selectedDepartmentId = "-2";
  bool loading = true;
  bool loadingMoreConversations = false;
  int _offset = 0;
  List<SMSConversation> conversations = [];
  bool applicationPaused = false;
  //conversations search values
  bool searchingForConversation = false;
  List<Contact> conversationsSearchContacts = [];
  List<CrmContact> conversationsSearchCrmContacts = [];
  List<SMSConversation> foundConversations = [];
  int unreadsCount = 0;

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
    _updateUnreadCount();
  }

  _updateUnreadCount() {
    fusionConnection.unreadMessages.getUnreads((unreads, fromServer) {
      if (fromServer) {
        int total = 0;
        for (var unread in unreads) {
          if (unread.departmentId != int.parse(selectedDepartmentId)) {
            total += unread.unread!;
          }
        }
        unreadsCount = total;
        notifyListeners();
      }
    });
  }

  void cancelNotificationsStream() {
    notificationsStream.cancel();
  }

  void _onForegroundNotificationReceived(RemoteMessage remoteMessage) {
    print("$DebugTag _onForegroundNotificationReceived");
    if (remoteMessage.notification != null) {
      lookupMessages(limit: 20);
      _updateUnreadCount();
    }
  }

  void refreshView({String? departmentId}) {
    lookupMessages(
        limit: 20,
        getAllMessages: departmentId != null ? false : true,
        departmentId: departmentId);
    notifyListeners();
  }

  void rebuildConversationListView() {
    notifyListeners();
  }

  void onAppStateChanged(AppLifecycleState state) {
    print("MDBM ChatsVM onAppStateChanged ${state.name}");
    if (state == AppLifecycleState.paused) {
      applicationPaused = true;
    }
    if (state == AppLifecycleState.resumed && applicationPaused) {
      applicationPaused = false;
      lookupMessages(limit: 20);
      _updateUnreadCount();
    }
  }

  String selectedDepartmentName() {
    String dpName = "";
    fusionConnection.smsDepartments.lookupDepartment(
      selectedDepartmentId,
      (departmentName) {
        dpName = departmentName;
      },
    );
    return dpName;
  }

  List<List<String>> groupOptions() {
    List<SMSDepartment> departments =
        fusionConnection.smsDepartments.allDepartments();
    List<List<String>> options = [];

    departments.sort((a, b) => a.groupName == "All Messages"
        ? -1
        : (a.groupName != "All Messages" && int.parse(a.id) < int.parse(b.id))
            ? -1
            : 1);
    for (SMSDepartment d in departments) {
      options.add([
        d.groupName ?? "",
        d.id,
        d.unreadCount.toString(),
        d.id,
        d.protocol ?? ""
      ]);
    }
    if (unreadsCount == 0) {
      options.removeWhere((element) => element.contains(DepartmentIds.Unread));
    }
    return options;
  }

  void onGroupChange(String newGroupId) {
    sharedPreferences.setString('selectedGroupId', newGroupId);
    selectedDepartmentId = newGroupId;
    if (_offset > 0) {
      _offset = 0;
    }
    conversations = [];
    lookupMessages();
    _updateUnreadCount();
  }

  lookupMessages(
      {int? limit, bool? getAllMessages, String? departmentId}) async {
    loading = true;
    notifyListeners();

    await fusionConnection.conversations.getConversations(
      getAllMessages != null && getAllMessages
          ? DepartmentIds.AllMessages
          : departmentId != null
              ? departmentId
              : selectedDepartmentId,
      limit ?? conversationsLimit,
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
        if (fromServer) {
          loadingMoreConversations = false;
          notifyListeners();
        }
      },
    );
    loading = false;
    if (_offset > conversations.length) {
      _offset = conversations.length;
    }
    // print("MDBM conversations offset $_offset");
    notifyListeners();
  }

  void loadMore() {
    loadingMoreConversations = true;
    _offset = conversationsLimit + _offset;
    lookupMessages();
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
    print("$DebugTag delete ${conversations.length}");
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
      print("$DebugTag deleted ${conversations.length}");
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
    print("$DebugTag new ${newConvos.length}");
    return newConvos;
  }

  void markConversationAsRead(SMSConversation conversation) async {
    await fusionConnection.conversations.markRead(conversation);
    if (selectedDepartmentId == DepartmentIds.Unread) {
      conversations.removeWhere(
          (element) => element.conversationId == conversation.conversationId);
    }
    _updateUnreadCount();
  }

  void _searchContacts(String query) {
    if (selectedDepartmentId == DepartmentIds.FusionChats) {
      fusionConnection.coworkers.search(query, (p0) {
        conversationsSearchContacts = p0;
        loading = false;
        notifyListeners();
      });
    } else {
      bool usesV2 = fusionConnection.settings.isV2User();
      if (!usesV2) {
        fusionConnection.contacts.search(query, 50, 0,
            (List<Contact> contacts, bool fromServer, bool fromPhonebook) {
          fusionConnection.integratedContacts.search(query, 50, 0,
              (List<Contact> crmContacts, bool fromServer, bool? hasMore) {
            conversationsSearchContacts = [...contacts, ...crmContacts];
            loading = false;

            notifyListeners();
          });
        });
      } else {
        fusionConnection.contacts.searchV2(query, 50, 0, false,
            (List<Contact> contacts, bool fromServer, bool fromPhonebook) {
          if (fromServer) {
            conversationsSearchContacts = contacts;
            loading = false;

            notifyListeners();
          }
        });
      }
    }
  }

  void searchConversations(String query) {
    loading = true;
    searchingForConversation = true;
    notifyListeners();

    debounce(() {
      if (query.trim().isEmpty) {
        searchingForConversation = false;
        loading = false;
        notifyListeners();
        return;
      }
      _searchContacts(query);
      fusionConnection.messages.searchV2(query, (
        List<SMSConversation> convos,
        List<CrmContact> crmContacts,
        List<Contact> contacts,
        bool fromServer,
      ) {
        if (fromServer) {
          foundConversations = convos;
          loading = false;
        }
        notifyListeners();
      });
    });
  }

  String getMyNumber() {
    String myPhoneNumber = "";
    SMSDepartment department = fusionConnection.smsDepartments.getDepartment(
      selectedDepartmentId == DepartmentIds.AllMessages
          ? DepartmentIds.Personal
          : selectedDepartmentId,
    );
    if (department.numbers.length > 0 &&
        department.id != DepartmentIds.AllMessages) {
      myPhoneNumber = department.numbers[0];
    }
    return myPhoneNumber;
  }

  Future<SMSConversation> getConversation(
    Contact contact,
    String number,
    String myNumber,
  ) async {
    return await fusionConnection.messages.checkExistingConversation(
      selectedDepartmentId,
      myNumber,
      [number],
      [contact],
    );
  }
}
