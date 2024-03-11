import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/phone_contact.dart';
import 'package:fusion_mobile_revamped/src/models/unreads.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:sqflite/sql.dart';
import 'dart:convert' as convert;

import '../backend/fusion_connection.dart';
import 'contact.dart';
import 'crm_contact.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';
import 'messages.dart';
import 'sms_departments.dart';

class SMSConversation extends FusionModel {
  List<CrmContact> crmContacts = [];
  List<Contact> contacts = [];
  String groupName = "";
  late String hash;
  bool isGroup = false;
  String lastContactTime = "";
  List<dynamic> members = [];
  SMSMessage? message;
  late String number;
  late String myNumber;
  late int unread;
  int? conversationId;
  late String selectedDepartmentId;
  bool isBroadcast = false;
  Map<String, dynamic>? filters;
  String? assigneeUid;
  FusionConnection fusionConnection = FusionConnection.instance;
  String contactName({Coworker? coworker}) {
    String name = "Unknown";
    for (Contact contact in contacts!) {
      if (contact.name != null && contact.name?.trim() != "") {
        name = contact.name ?? "Unknown";
      }
    }
    for (CrmContact contact in crmContacts) {
      if (contact.name != null && contact.name?.trim() != "") {
        name = contact.name ?? "Unknown";
      }
    }

    if (this.isGroup) {
      name = this.hash.replaceAll(':', ',').formatPhone();
    }
    if (coworker != null) {
      name = "${coworker.firstName} ${coworker.lastName}";
    }
    return name;
  }

  SMSConversation.build(
      {required this.myNumber,
      required this.number,
      this.message,
      required this.contacts,
      required this.crmContacts,
      this.conversationId,
      required this.isGroup,
      required this.hash,
      this.selectedDepartmentId = DepartmentIds.Personal}) {
    this.hash = this.hash ?? this.myNumber + ":" + this.number;
    this.unread = 0;
    if (this.message != null) {
      this.lastContactTime = message!.time.date!;
    }
  }

  SMSConversation.copy(SMSConversation c) {
    conversationId = c.conversationId;
    this.groupName = c.groupName;
    this.isGroup = c.isGroup;
    this.lastContactTime = c.lastContactTime;
    this.lastContactTime = c.lastContactTime;
    this.myNumber = c.myNumber!.toLowerCase();
    this.number = c.number!.toLowerCase();
    this.members = c.members;
    this.message = c.message;
    this.unread = c.unread;
    this.crmContacts = c.crmContacts;
    this.contacts = c.contacts;
    this.hash = c.hash;
    this.isBroadcast = c.isBroadcast;
    this.filters = c.filters;
    this.assigneeUid = c.assigneeUid;
  }

  SMSConversation(Map<String, dynamic> map) {
    String? toNumber =
        map['lastMessage']['from'].toString().toLowerCase() == map['myNumber']
            ? map['lastMessage']['to']
            : map['lastMessage']['from'];
    this.conversationId = map['conversationId'] ?? map['groupId'];
    this.groupName = map['groupName'] ?? '';
    this.isGroup = map['isGroup'];
    this.lastContactTime = map['lastContactTime'];
    this.myNumber = map['myNumber'].toString().toLowerCase();
    this.number = map['isGroup'] != null && map['isGroup'] == true
        ? map['groupId'].toString()
        : toNumber!.toLowerCase();
    this.members = map['conversationMembers']; //map['members'];
    this.message = map['message'];
    this.unread = map['unreadCount'];
    this.crmContacts = map['crm_contacts'] ?? [];
    this.contacts = map['contacts'] ?? [];
    this.hash = map['hash'];
    this.isBroadcast = map['isBroadcast'] ?? false;
    this.filters = map['filters'];
    this.assigneeUid = map['assigneeUid'];
  }

  serialize() {
    return convert.jsonEncode({
      'conversationId': this.conversationId,
      'hash': this.hash,
      'groupName': this.groupName,
      'isGroup': this.isGroup,
      'lastContactTime': this.lastContactTime,
      'myNumber': myNumber.toLowerCase(),
      'number': number.toLowerCase(),
      'members': members,
      'message': message?.serialize(),
      'unread': unread,
      'isBroadcast': this.isBroadcast,
      'filters': this.filters,
      'assigneeUid': this.assigneeUid,
      'crmContacts': crmContacts
          .map((CrmContact c) {
            return c.serialize();
          })
          .toList()
          .cast<String>(),
      'contacts': contacts
          .map((Contact c) {
            return c.serialize();
          })
          .toList()
          .cast<String>(),
    });
  }

  SMSConversation.unserialize(String dataString) {
    Map<String, dynamic> data = convert.jsonDecode(dataString);
    this.conversationId =
        data['groupId'] != null ? data['groupId'] : data['conversationId'];
    this.groupName = data['groupName'] ?? '';
    this.isGroup =
        (data['isGroup'] == 1 || data['isGroup'] == true) ? true : false;
    this.lastContactTime = data['lastContactTime'];
    this.lastContactTime = data['lastContactTime'];
    this.myNumber = data['myNumber'].toLowerCase();
    this.number = data['to'] != null
        ? data['to'].toLowerCase()
        : data['number'].toLowerCase();
    this.members = data['conversationMembers'] ?? [];
    this.message = SMSMessage.unserialize(data['message']);
    this.unread = data['unread'];
    this.crmContacts = data['crmContacts']
        .cast<String>()
        .map((String s) {
          return CrmContact.unserialize(s);
        })
        .toList()
        .cast<CrmContact>();
    this.contacts = data['contacts']
        .cast<String>()
        .map((String s) {
          return Contact.unserialize(s);
        })
        .toList()
        .cast<Contact>();
    this.hash = data['hash'];
    this.isBroadcast = data['isBroadcast'] ?? false;
    this.filters = data['filters'];
    this.assigneeUid = data['assigneeUid'];
  }

  String searchString() {
    return message?.message != null
        ? [number, myNumber, message?.message].join(' ')
        : "";
  }

  String getDepartmentId({required FusionConnection fusionConnection}) {
    return fusionConnection.smsDepartments
            .getDepartmentByPhoneNumber(myNumber)
            ?.id ??
        fusionConnection.smsDepartments.getDepartment("-2").id;
  }

  Coworker? getCoworker({required FusionConnection fusionConnection}) {
    Coworker? _coworker;
    fusionConnection.coworkers
        .getRecord(number, (coworker) => _coworker = coworker);
    return _coworker;
  }

  @override
  String getId() => this.hash;
}

class SMSConversationsStore extends FusionStore<SMSConversation> {
  String _id_field = 'hash';

  SMSConversationsStore(FusionConnection _fusionConnection)
      : super(_fusionConnection);

  @override
  storeRecord(SMSConversation record) {
    super.storeRecord(record);
    persist(record);
  }

  @override
  removeRecord(String id) {
    super.removeRecord(id);
    fusionConnection.db
        .delete('sms_conversation', where: 'id = ?', whereArgs: [id]);
  }

  persist(SMSConversation record) {
    fusionConnection.db.delete('sms_conversation',
        where: 'id = ?', whereArgs: [record.getId()]);
    fusionConnection.db.insert(
        'sms_conversation',
        {
          'id': record.getId(),
          'groupName': record.groupName,
          'isGroup': record.isGroup ? 1 : 0,
          'lastContactTime': DateTime.parse(record.lastContactTime)
                  .toLocal()
                  .millisecondsSinceEpoch /
              1000,
          'searchString': record.searchString(),
          'number': record.isGroup ? record.conversationId : record.number,
          'myNumber': record.myNumber,
          'unread': record.unread,
          'raw': record.serialize(),
          'conversationId': record.conversationId,
          'isBroadcast': record.isBroadcast.toString(),
          'filters': record.filters,
          'assigneeUid': record.assigneeUid
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  getPersisted(
    String groupId,
    int limit,
    int offset,
    Function(List<SMSConversation> conversations, bool fromServer) callback,
  ) {
    if (fusionConnection.smsDepartments.allDepartments().isEmpty) {
      return callback([], false);
    }
    SMSDepartment group = fusionConnection.smsDepartments.lookupRecord(groupId);
    fusionConnection.db
        .query('sms_conversation',
            limit: limit,
            offset: offset,
            orderBy: 'lastContactTime DESC',
            where: 'myNumber in ("' + group.numbers.join('","') + '")')
        .then((List<Map<String, dynamic>> results) {
      List<SMSConversation> list = [];
      for (Map<String, dynamic> result in results) {
        list.add(SMSConversation.unserialize(result['raw']));
      }
      callback(list, false);
    });
  }

  searchPersisted(String query, String groupId, int limit, int offset,
      Function(List<SMSConversation> conversations, bool fromServer) callback) {
    SMSDepartment group = fusionConnection.smsDepartments.lookupRecord(groupId);
    if (group != null) {
      fusionConnection.db.query('sms_conversation',
          limit: limit,
          offset: offset,
          where: 'myNumber in ("' +
              group.numbers.join('","') +
              '") AND searchString Like ?',
          whereArgs: [
            "%" + query + "%"
          ]).then((List<Map<String, dynamic>> results) {
        List<SMSConversation> list = [];
        for (Map<String, dynamic> result in results) {
          list.add(SMSConversation.unserialize(result['raw']));
        }
        callback(list, false);
      });
    }
  }

  getConversations(
    String groupId,
    int limit,
    int offset,
    Function(
      List<SMSConversation> conversations,
      bool fromServer,
      String departmentId,
      String? errorMessage,
    ) callback,
  ) async {
    SMSConversation? lastMessageFailed = null;
    getPersisted(groupId, limit, offset, (savedConvos, fromserver) {
      callback(savedConvos, fromserver, groupId, "");
      lastMessageFailed = savedConvos
              .where((convo) => convo.message?.messageStatus == "offline")
              .isNotEmpty
          ? savedConvos
              .where((convo) => convo.message?.messageStatus == "offline")
              .toList()
              .first
          : null;
    });
    fusionConnection.refreshUnreads();
    List<PhoneContact> phoneContacts =
        fusionConnection.phoneContacts.getRecords();
    List<Coworker> coworkers = fusionConnection.coworkers.getRecords();
    try {
      fusionConnection.apiV2Call(
        "get",
        "/messaging/group/${groupId}/conversations",
        {
          // 'numbers': numbers.join(","),
          'limit': limit,
          'offset': offset,
          // 'group_id': groupId
        },
        callback: (Map<String, dynamic> data) async {
          List<SMSConversation> convos = [];
          if (!data.containsKey("items")) {
            return toast("Couldn't get recent conversaions list",
                duration: Duration(seconds: 3));
          }
          for (Map<String, dynamic> item in data['items']) {
            List<CrmContact> leads = [];
            List<Contact> contacts = [];

            if (item['conversationMembers'] != null) {
              for (Map<String, dynamic> obj in item['conversationMembers']) {
                List<dynamic> convoMembersContacts = obj['contacts'];
                List<dynamic> convoMembersLeads = obj['leads'] ?? [];
                dynamic number = obj['number'];
                if (convoMembersContacts.length > 0) {
                  convoMembersContacts.forEach((contact) {
                    contacts.add(Contact.fromV2(contact));
                  });
                } else if (convoMembersLeads.length > 0) {
                  convoMembersLeads.forEach((lead) {
                    contacts.add(CrmContact.fromExpanded(lead).toContact());
                  });
                } else if (obj['number'].toString().contains("@")) {
                  if (coworkers.isNotEmpty) {
                    Coworker? _coworker = coworkers
                            .where((c) =>
                                c.uid!.toLowerCase() ==
                                obj['number'].toString().toLowerCase())
                            .isNotEmpty
                        ? coworkers
                            .where((c) =>
                                c.uid!.toLowerCase() ==
                                obj['number'].toString().toLowerCase())
                            .first
                        : null;
                    if (_coworker != null) {
                      contacts.add(_coworker.toContact());
                    } else {
                      contacts.add(Contact.fake(number));
                    }
                  }
                } else if (convoMembersContacts.length == 0 &&
                    convoMembersLeads.length == 0 &&
                    number != '') {
                  PhoneContact? phoneContact = phoneContacts.isNotEmpty
                      ? await fusionConnection.phoneContacts.searchDb(number)
                      : null;
                  if (phoneContact != null) {
                    contacts.add(phoneContact.toContact());
                  } else {
                    contacts.add(Contact.fake(number));
                  }
                }
              }
            }

            item['contacts'] = contacts;
            item['crm_contacts'] = leads;
            if (item['lastMessage'] != null) {
              item['message'] = SMSMessage.fromV2(item['lastMessage']);
            }
            if (lastMessageFailed != null &&
                item['groupId'] == lastMessageFailed!.conversationId) {
              item['message'] = lastMessageFailed!.message;
            }
            if (item['message'] == null) break;
            SMSConversation convo = SMSConversation(item);
            storeRecord(convo);
            convos.add(convo);
          }
          callback(convos, true, groupId, "");
        },
      );
    } catch (e) {
      callback([], true, groupId, "Server Error");
    }
  }

  void markRead(SMSConversation convo) {
    convo.unread = 0;
    storeRecord(convo);
    fusionConnection.refreshUnreads();
    fusionConnection.apiV2Call("post", "/messaging/markRead", {
      "from": convo.number,
      "to": convo.myNumber,
    });
  }

  void clearPersistedConvoMessages(SMSConversation convo) {
    fusionConnection.db.delete('sms_message',
        where: '(`to` = ? and `from` = ?) or (`from` = ? and `to` = ?)',
        whereArgs: [
          convo.myNumber,
          convo.number,
          convo.myNumber,
          convo.number
        ]);
  }

  void deleteConversation(SMSConversation convo, String departmentId) {
    this.removeRecord(convo.getId());
    clearPersistedConvoMessages(convo);

    fusionConnection.apiV2Call(
        "post",
        "/messaging/group/${departmentId}/conversations/${convo.conversationId}/archive",
        {},
        callback: null);
  }

  void markUnread(
      String messageId, SMSConversation conversation, Function closeConvo) {
    conversation.unread = 1;
    storeRecord(conversation);
    fusionConnection.apiV2Call(
        "get", "/messaging/message/$messageId/markUnread", {},
        callback: closeConvo());
  }

  Future<bool> renameConvo(int convoId, String newName) async {
    bool success = false;
    await fusionConnection.apiV2Call(
        "put",
        "/messaging/group/-2/conversations/${convoId}/rename",
        {"name": newName}, callback: (Map<String, dynamic> data) {
      if (data.containsKey('groupName') && data['groupName'] == newName) {
        success = true;
      }
    });
    return success;
  }

  void editConvoAssignment(
      {required String coworkerUid, required SMSConversation convo}) {
    fusionConnection.apiV2Call("post", "/messaging/editAssignment", {
      "assignee": coworkerUid,
      "from": convo.myNumber,
      "to": convo.number,
      "isGroup": convo.isGroup,
      "convoId": convo.conversationId
    }, callback: (Map<String, dynamic> data) {
      if (data.containsKey('assignee') && data['assignee'] != "") {
        convo.assigneeUid = data['assignee'];
      }
    });
  }

  void sendTypingEvent(SMSConversation convo, String departmentId) {
    fusionConnection.apiV2Call(
      "post",
      "/client/typingEvent",
      {
        "groupConversationId": convo.conversationId,
        "groupId": departmentId,
        "to": convo.number,
        "uid": fusionConnection.getUid(),
      },
    );
  }
}
