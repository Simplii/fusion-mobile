import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/models/user_settings.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/viewModels/changeNotifier.dart';
import 'package:image_picker/image_picker.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../backend/fusion_connection.dart';
import '../messages/messages_list.dart';
import '../utils.dart';
import 'carbon_date.dart';
import 'contact.dart';
import 'conversations.dart';
import 'crm_contact.dart';
import 'fusion_model.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'fusion_store.dart';
import 'dart:convert' as convert;

class SMSMessage extends FusionModel {
  bool convertedMms = false;
  String? domain;
  late String from;
  bool fromMe = false;
  late String id;
  bool isGroup = false;
  bool media = false;
  late String message;
  String messageStatus = "";
  String? mime;
  late bool read;
  String? scheduledAt;
  late int smsWebhookId;
  late CarbonDate time;
  late String to;
  late String type;
  late int unixtime;
  String? user;
  String errorMessage = "";
  int broadcastConvoId = 0;
  List<String> typingUsers = [];
  String userTyping1 = "";
  String userTyping2 = "";

  SMSMessage(Map<String, dynamic> map) {
    Map<String, dynamic> timeDateObj = checkDateObj(map['time'])!;
    this.convertedMms = map.containsKey('converted_mms') ? true : false;
    this.domain = map['domain'].runtimeType == String ? map['domain'] : null;
    this.from = map['from'].toString().toLowerCase();
    this.fromMe = map['from_me'];
    this.id = map['id'].toString();
    this.isGroup = map['is_group'];
    //this.media = map['media'];
    this.message = map['message'];
    this.messageStatus = map['message_status'];
    this.mime = map['mime'];
    this.read = map['read'] == "1";
    this.scheduledAt = ((map.containsKey('scheduled_at') &&
            map['scheduled_at'].runtimeType == Map)
        ? CarbonDate(map['scheduled_at']).date
        : null);
    this.smsWebhookId =
        map['sms_webhook_id'].runtimeType == int ? map['sms_webhook_id'] : 0;
    this.time = CarbonDate(timeDateObj);
    this.to = map['to'].toString().toLowerCase();
    this.type = map['type'];
    this.unixtime = map['unixtime'] ?? 0;
    this.user = map['user'].runtimeType == String ? map['user'] : null;
    this.broadcastConvoId = map['broadcastConversationId'] ?? 0;
    this.errorMessage = map['errorMessage'] ?? "";
  }

  SMSMessage.fromV2(Map<String, dynamic> map) {
    String time = map.containsKey('scheduledAt') && map['scheduledAt'] != null
        ? map['scheduledAt']
        : map['time'];
    String? status = map['message_status'] ?? map['status'];
    this.convertedMms = map.containsKey('converted_mms') ? true : false;
    this.domain = map['user'].runtimeType == String
        ? map['user'].toString().replaceFirst(RegExp(".*@"), "")
        : null;
    this.from = map['from'].toString().toLowerCase();
    this.fromMe = map['fromMe'] ?? false;
    this.id = map['id'].toString();
    this.isGroup = map['is_group'] ?? map['isGroup'];
    this.message = map['message'];
    this.messageStatus = status ?? "";
    this.mime = map['mime'];
    this.read = map['read'] == 1;
    this.scheduledAt =
        ((map.containsKey('scheduledAt')) ? map['scheduledAt'] : null);
    this.smsWebhookId =
        map['smsWebhookId'].runtimeType == int ? map['smsWebhookId'] : 0;
    this.time = CarbonDate.fromDate(map['time']);
    this.to = map['to'].toString().toLowerCase();
    this.type = "sms";
    this.unixtime =
        DateTime.parse(time).toLocal().millisecondsSinceEpoch ~/ 1000;
    this.user = map['user'].runtimeType == String
        ? map['user'].toString().replaceFirst(RegExp("@.*"), "")
        : null;
    this.broadcastConvoId = map['broadcastConversationId'] ?? 0;
    this.errorMessage = map.containsKey("errorMessage")
        ? map['errorMessage']
        : map['error_message'] ?? "";
  }

  serialize() {
    return convert.jsonEncode({
      'convertedMms': convertedMms,
      'domain': domain,
      'from': from,
      'fromMe': fromMe,
      'id': id,
      'isGroup': isGroup,
      'media': media,
      'message': message,
      'messageStatus': messageStatus,
      'mime': mime,
      'read': read,
      'scheduledAt': scheduledAt,
      'smsWebhookId': smsWebhookId,
      'time': time.serialize(),
      'to': to,
      'type': type,
      'unixtime': unixtime,
      'user': user,
      'broadcastConvoId': broadcastConvoId,
      'errorMessage': errorMessage,
      'typingUsers': typingUsers,
      'userTyping1': userTyping1,
      'userTyping2': userTyping2,
    });
  }

  SMSMessage.unserialize(String data) {
    Map<String, dynamic> obj = convert.jsonDecode(data);
    this.convertedMms = obj['convertedMms'];
    this.domain = obj['domain'];
    this.from = obj['from'];
    this.fromMe = obj['fromMe'] ?? false;
    this.id = obj['id'];
    this.isGroup = obj['isGroup'];
    this.media = obj['media'] ?? false;
    this.message = obj['message'];
    this.messageStatus = obj['messageStatus'] ?? "";
    this.mime = obj['mime'];
    this.read = obj['read'];
    if (obj['scheduledAt'] != null) this.scheduledAt = obj['scheduledAt'];
    this.smsWebhookId = obj['smsWebhookId'];
    if (obj['time'] != null) this.time = CarbonDate.unserialize(obj['time']);
    this.to = obj['to'];
    this.type = obj['type'];
    this.unixtime = obj['unixtime'];
    this.user = obj['user'];
    this.broadcastConvoId = obj['broadcastConvoId'] ?? 0;
    this.errorMessage = obj['errorMessage'] ?? "";
  }

  SMSMessage.offline(
      {required String from,
      required bool isGroup,
      required String text,
      required String to,
      String? user,
      required String messageId,
      String? schedule}) {
    String date = DateTime.now().toString();
    this.convertedMms = false;
    this.domain = null;
    this.from = from;
    this.fromMe = true;
    this.id = messageId;
    this.isGroup = isGroup;
    this.message = text;
    this.messageStatus = 'offline';
    this.mime = null;
    this.read = true;
    this.scheduledAt = schedule;
    this.smsWebhookId = 0;
    this.time = CarbonDate.fromDate(date);
    this.to = to;
    this.type = "sms";
    this.unixtime = DateTime.parse(date).millisecondsSinceEpoch ~/ 1000;
    this.user = user;
    this.broadcastConvoId = 0;
    this.errorMessage = "";
  }

  SMSMessage.typing({
    required String from,
    required bool isGroup,
    required String text,
    required String to,
    required String user,
    required String messageId,
    required String domain,
  }) {
    String date = DateTime.now().toString();
    this.convertedMms = false;
    this.domain = domain;
    this.from = from;
    this.fromMe = false;
    this.id = messageId;
    this.isGroup = isGroup;
    this.message = text;
    this.messageStatus = 'typing';
    this.mime = null;
    this.read = true;
    this.scheduledAt = null;
    this.smsWebhookId = 0;
    this.time = CarbonDate.fromDate(date);
    this.to = to;
    this.type = "sms";
    this.unixtime = DateTime.parse(date).millisecondsSinceEpoch ~/ 1000;
    this.user = user;
    this.broadcastConvoId = 0;
    this.errorMessage = "";
    this.typingUsers.add(user);
  }
  @override
  String getId() => this.id!.toLowerCase();
}

class SMSMessageSubscription {
  final SMSConversation _conversation;
  final Function(List<SMSMessage>) _callback;

  SMSMessageSubscription(this._conversation, this._callback);

  testMatches(SMSMessage message) {
    if (_conversation.isBroadcast) {
      return message.broadcastConvoId == _conversation.conversationId;
    } else {
      return ((message.from == _conversation.number &&
              message.to == _conversation.myNumber) ||
          (message.to == _conversation.number &&
              message.from == _conversation.myNumber));
    }
  }

  sendMatching(List<SMSMessage> items) {
    List<SMSMessage> list = [];

    for (SMSMessage item in items) {
      if (testMatches(item)) {
        list.add(item);
      }
    }

    this._callback(list);
  }
}

class SMSMessagesStore extends FusionStore<SMSMessage> {
  String _id_field = 'id';
  Map<String, SMSMessageSubscription> subscriptions = {};
  Map<String?, bool> notifiedMessages = {};

  SMSMessagesStore(FusionConnection _fusionConnection)
      : super(_fusionConnection);
  final notification = VMChangeNotifier(null);

  @override
  removeRecord(id) {
    super.removeRecord(id);
    fusionConnection.db.delete('sms_message', where: 'id = ?', whereArgs: [id]);
  }

  notifyMessage(SMSMessage message) {
    if (!notifiedMessages.containsKey(message.id)) {
      notifiedMessages[message.id] = true;

      List<SMSConversation> convos =
          fusionConnection.conversations.getRecords();

      SMSConversation? convo = convos
          .where((element) => element.isGroup
              ? element.number == message.to
              : element.myNumber == message.to)
          .firstOrNull;

      if (convo != null) {
        convo.message = message;
        convo.unread = convo.unread + 1;
        convo.lastContactTime =
            DateTime.parse(message.time.date ?? "").toLocal().toIso8601String();
        fusionConnection.conversations.storeRecord(convo);
        notification.update(convo);
      }

      new Future.delayed(Duration(minutes: 2), () {
        notifiedMessages.remove(message.id);
      });
    }
  }

  void viewUpdated() => notification.reset();

  subscribe(SMSConversation conversation, Function(List<SMSMessage>) callback) {
    String name = randomString(20);
    subscriptions[name] = SMSMessageSubscription(conversation, callback);
    return name;
  }

  persist(SMSMessage record) async {
    await fusionConnection.db
        .delete('sms_message', where: 'id = ?', whereArgs: [record.getId()]);
    await fusionConnection.db.insert(
        'sms_message',
        {
          'id': record.getId(),
          'from': record.from!.toLowerCase(),
          'fromMe': record.fromMe != null && record.fromMe! ? 1 : 0,
          'media': record.media != null && record.media! ? 1 : 0,
          'message': record.message,
          'mime': record.mime ?? '',
          'read': record.read != null && record.read! ? 1 : 0,
          'time': record.unixtime,
          'to': record.to!.toLowerCase(),
          'user': record.user,
          'raw': record.serialize(),
          'broadcastConvoId': record.broadcastConvoId,
          'errorMessage': record.errorMessage
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  clearSubscription(name) {
    if (subscriptions.containsKey(name)) {
      subscriptions.remove(name);
    }
  }

  @override
  storeRecord(SMSMessage message) {
    super.storeRecord(message);

    for (SMSMessageSubscription subscription in subscriptions.values) {
      subscription.sendMatching([message]);
    }

    persist(message);
  }

  _sendMediaMessage(
    XFile file,
    SMSConversation conversation,
    String? departmentId,
    dynamic generatedConvoId,
    Function? callback,
    Function largeMMSCallback,
    schedule,
  ) async {
    int fileSize = await file.length();
    bool _canSendLargeMMS = true;

    if (fileSize > 1024 * 1024 * 2) {
      fusionConnection.settings!.options.forEach((key, value) {
        if (key == "enabled_features" &&
            !value.contains("Large MMS Messages")) {
          _canSendLargeMMS = false;
          largeMMSCallback();
        }
      });
    }

    if (_canSendLargeMMS) {
      fusionConnection.apiV2Multipart(
          "POST",
          "/messaging/group/${departmentId}/conversations/${generatedConvoId ?? conversation.conversationId}/messages",
          {
            'myIdentifier': conversation.myNumber,
            'schedule': schedule != null ? schedule.toUtc().toString() : null,
            'isMms': true,
            'text': '',
            'isGroup': conversation.isGroup
          },
          [
            http.MultipartFile.fromBytes("file", await file.readAsBytes(),
                filename: basename(file.path),
                contentType: MediaType.parse(lookupMimeType(file.path)!))
          ], callback: (Map<String, dynamic> data) {
        conversation.number = data['to'];
        SMSMessage message = SMSMessage.fromV2(data);
        conversation.message = message;
        conversation.lastContactTime = DateTime.now().toLocal().toString();
        storeRecord(message);
        if (conversation.conversationId != null) {
          fusionConnection.conversations.storeRecord(conversation);
        }
        callback!();
      });
    }
  }

  Future<SMSConversation> checkExistingConversation(String departmentId,
      String myNumber, List<String> numbers, List<Contact> contacts) async {
    SMSConversation convo = SMSConversation.build(
        myNumber: myNumber,
        contacts: contacts,
        crmContacts: [],
        number: numbers.join(','),
        isGroup: numbers.length > 1,
        hash: myNumber + ':' + numbers.join(':'));
    await fusionConnection.apiV2Call(
        "post", "/messaging/group/${departmentId}/conversations/existing", {
      'identifiers': [myNumber, ...numbers]
    }, callback: (Map<String, dynamic> data) {
      if (data['lastMessage'] != null) {
        List<CrmContact> leads = [];
        for (Map<String, dynamic> obj in data['conversationMembers']) {
          List<dynamic> convoMembersLeads = obj['leads'];
          if (convoMembersLeads != null &&
              convoMembersLeads.length > 0 &&
              !fusionConnection.settings.usesV2) {
            convoMembersLeads.forEach((lead) {
              leads.add(CrmContact.fromExpanded(lead));
            });
          }
        }
        convo = SMSConversation(data);
        convo.crmContacts = leads;
        convo.contacts = contacts;
      } else {
        convo = SMSConversation.build(
            myNumber: myNumber,
            contacts: contacts,
            crmContacts: [],
            number: numbers.join(','),
            isGroup: numbers.length > 1,
            hash: myNumber + ':' + numbers.join(':'));
      }
    });

    return convo;
  }

  sendMessage(
    String? text,
    SMSConversation conversation,
    String? departmentId,
    XFile? mediaFile,
    Function(SMSMessage)? callback,
    Function largeMMSCallback,
    DateTime? schedule,
  ) async {
    if (conversation.conversationId != null) {
      if (mediaFile != null) {
        _sendMediaMessage(
          mediaFile,
          conversation,
          departmentId,
          null,
          callback,
          largeMMSCallback,
          schedule,
        );
      } else {
        fusionConnection.apiV2Call(
            "post",
            "/messaging/group/${departmentId}/conversations/${conversation.conversationId}/messages",
            {
              'myIdentifier': conversation.myNumber,
              'schedule': schedule != null ? schedule.toUtc().toString() : null,
              'isMms': false,
              'text': text,
              'isGroup': conversation.isGroup
            }, callback: (Map<String, dynamic> data) {
          if (data.containsKey("success") && !data['success']) {
            return toast("Message did not send due to ${data['error']}");
          }
          SMSMessage message = SMSMessage.fromV2(data);
          conversation.message = message;
          conversation.lastContactTime = DateTime.now().toLocal().toString();
          storeRecord(message);
          fusionConnection.conversations.storeRecord(conversation);
          if (callback != null) {
            callback(message);
          }
        });
      }
    } else {
      List<String> numbers = conversation.number!.split(',');

      fusionConnection
          .apiV2Call("post", "/messaging/group/${departmentId}/conversations", {
        'identifiers': [conversation.myNumber, ...numbers]
      }, callback: (Map<String, dynamic> data) async {
        conversation.conversationId = data['groupId'];
        if (mediaFile != null) {
          var generatedConvoId = data['groupId'];
          _sendMediaMessage(
            mediaFile,
            conversation,
            departmentId,
            generatedConvoId,
            callback,
            largeMMSCallback,
            schedule,
          );
        } else {
          fusionConnection.apiV2Call(
              "post",
              "/messaging/group/${departmentId}/conversations/${data['groupId']}/messages",
              {
                'myIdentifier': data['myNumber'],
                'schedule':
                    schedule != null ? schedule.toUtc().toString() : null,
                'isMms': false,
                'text': text,
                'isGroup': data['isGroup']
              }, callback: (Map<String, dynamic> data) {
            conversation.number = data['to'];
            SMSMessage message = SMSMessage.fromV2(data);
            conversation.message = message;
            storeRecord(message);
            if (callback != null) {
              callback(message);
            }
          });
        }
      });
    }
  }

  search(
      String query,
      Function(List<SMSConversation> conversations,
              List<CrmContact> crmContacts, List<Contact> Contacts)
          callback) {
    if (query.trim().length == 0) {
      return;
    }

    List<SMSConversation> matchedConversations = [];
    List<CrmContact> matchedCrmContacts = [];
    List<Contact> matchedContacts = [];

    Function() _sendFromPersisted = () {
      callback(matchedConversations, matchedCrmContacts, matchedContacts);
    };

    fusionConnection.conversations
        .searchPersisted(query, DepartmentIds.AllMessages, 100, 0,
            (List<SMSConversation> convos, fromHttp) {
      matchedConversations = convos;
      _sendFromPersisted();
    });

    fusionConnection.contacts.searchPersisted(query, 100, 0,
        (List<Contact> contacts, bool fromServer, bool fromPhonebook) {
      matchedContacts = contacts;
      _sendFromPersisted();
    });

    fusionConnection.apiV1Call("get", "/chat/search/flat", {
      'query': query,
      'my_numbers': "8014569812",
    }, callback: (Map<String, dynamic> data) {
      Map<String?, Contact> contacts = {};
      Map<String, CrmContact> crmContacts = {};
      Map<String, SMSMessage> messages = {};
      Map<String, SMSConversation> conversations = {};

      for (Map<String, dynamic> item in data['agg']['contacts']) {
        contacts[item['id']] = Contact(item);
      }

      for (Map<String, dynamic> item in data['agg']['leads']) {
        crmContacts[item['id'].toString()] = CrmContact.fromExpanded(item);
      }

      Map<String, dynamic> convoslist = {};

      if (data['agg']['conversations'] is List<dynamic>) {
        convoslist = {}; //data['agg']['conversations'];
      }

      for (String key in convoslist.keys) {
        List<Contact?> contactsList =
            (convoslist[key]['contacts'] as List<dynamic>).map((dynamic i) {
          return contacts[i.toString()];
        }).toList();
        List<CrmContact?> leadsList =
            (convoslist[key]['leads'] as List<dynamic>).map((dynamic i) {
          return crmContacts[i.toString()];
        }).toList();

        Map<String, dynamic> item = convoslist[key];
        item['leads'] = leadsList;
        item['contacts'] = contactsList;
        item['number'] = item['their_number'];
        SMSConversation convo = SMSConversation(item);
        conversations[key] = convo;
      }

      List<SMSConversation> fullConversations = [];
      for (Map<String, dynamic> item in data['items']) {
        SMSMessage message = SMSMessage(item);
        if (item['conversation_id'] != null &&
            conversations.containsKey(item['conversation_id'])) {
          SMSConversation convo = conversations[item['conversation_id']]!;
          SMSConversation newConvo = SMSConversation.copy(convo);
          newConvo.message = message;
          fullConversations.add(newConvo);
        }
      }

      callback(fullConversations, crmContacts.values.toList(),
          contacts.values.toList());
    });
  }

  searchV2(
      String query,
      Function(List<SMSConversation> conversations,
              List<CrmContact> crmContacts, List<Contact> Contacts)
          callback) {
    if (query.trim().length == 0) {
      return;
    }

    List<SMSConversation> matchedConversations = [];

    Function() _sendFromPersisted = () {
      callback(matchedConversations, [], []);
    };

    fusionConnection.conversations
        .searchPersisted(query, DepartmentIds.AllMessages, 100, 0,
            (List<SMSConversation> convos, fromHttp) {
      matchedConversations = convos;
      _sendFromPersisted();
    });

    fusionConnection.apiV2Call('get', '/messaging/group/-2/conversations/query',
        {"limit": 200, "offse": 0, "query": query},
        callback: (Map<String, dynamic> data) {
      List<SMSConversation> fullConversations = [];
      List<Contact> contacts = [];

      for (Map<String, dynamic> item in data['items']) {
        List<Contact> contactsList = [];
        List<CrmContact> leadsList = [];

        for (Map<String, dynamic> obj in item['conversationMembers']) {
          List<dynamic> c = obj['contacts'];
          List<dynamic>? convoMembebersLeads = obj['leads'];
          dynamic number = obj['number'];
          if (c.length > 0) {
            Contact _contact = Contact.fromV2(c.last);
            contactsList.add(_contact);
            List<Contact> contactExist =
                contacts.where((e) => e.id == _contact.id).toList();
            contactExist.isEmpty ? contacts.add(_contact) : null;
          } else if (convoMembebersLeads!.length > 0) {
            convoMembebersLeads.forEach((lead) {
              contactsList.add(CrmContact(lead).toContact());
            });
          } else if (c.length == 0 &&
              convoMembebersLeads.length == 0 &&
              number != '') {
            contactsList.add(Contact.fake(number));
          }
        }

        SMSMessage message = SMSMessage.fromV2(item['lastMessage']);
        SMSConversation convo = SMSConversation(item);
        convo.message = message;
        convo.contacts = contactsList;
        convo.crmContacts = leadsList;
        fullConversations.add(convo);
      }

      callback(fullConversations, [], contacts);
    });
  }

  Future<void> getPersisted(SMSConversation convo, int limit, int offset,
      Function(List<SMSMessage>, bool) callback) async {
    await fusionConnection.db
        .query('sms_message',
            limit: limit,
            offset: offset,
            where: convo.conversationId != null &&
                    convo.isGroup &&
                    convo.isBroadcast
                ? '`broadcastConvoId` = ?'
                : convo.conversationId != null &&
                        convo.isGroup &&
                        !convo.isBroadcast
                    ? '`to` = ?'
                    : '(`to` = ? and `from` = ?) or (`from` = ? and `to` = ?)',
            orderBy: "id desc",
            whereArgs: convo.conversationId != null && convo.isGroup!
                ? [convo.conversationId]
                : [
                    convo.myNumber!.toLowerCase(),
                    convo.number!.toLowerCase(),
                    convo.myNumber!.toLowerCase(),
                    convo.number!.toLowerCase()
                  ])
        .then((List<Map<String, dynamic>> results) {
      List<SMSMessage> list = [];
      for (Map<String, dynamic> result in results) {
        list.add(SMSMessage.unserialize(result['raw']));
      }
      callback(list, false);
    });
  }

  getMessages(
      SMSConversation convo,
      int limit,
      int offset,
      Function(List<SMSMessage> messages, bool fromServer) callback,
      String? departmentId) async {
    List<SMSMessage> failedMesages = [];
    await getPersisted(convo, limit, offset, (messages, fromServer) {
      callback(messages, fromServer);
      failedMesages = messages
          .where((SMSMessage m) => m.messageStatus == "offline")
          .toList();
    });

    if (convo.conversationId != null && convo.isGroup) {
      fusionConnection.apiV2Call(
          "get",
          "/messaging/group/${departmentId}/conversations/${convo.conversationId}/messages",
          {
            'isGroup': convo.isGroup,
            // 'their_numbers': convo.number,
            'limit': limit,
            'offset': offset,
            // 'group_id': -2
          }, callback: (Map<String, dynamic> data) {
        List<SMSMessage> messages = [];
        if (data.containsKey("success") && !data['success']) {
          return toast("${data['error']}");
        }
        for (Map<String, dynamic> item in data['items']) {
          //test getting a message SMSV2
          SMSMessage message = SMSMessage.fromV2(item);
          storeRecord(message);
          messages.add(message);
        }
        callback([...messages, ...failedMesages], true);
      });
    } else if (convo.conversationId == null && convo.isGroup) {
      callback([], true);
    } else {
      fusionConnection.apiV2Call(
          "get",
          "/messaging/group/${departmentId}/conversations/${convo.number}/${convo.myNumber}/messages",
          {
            'isGroup': convo.isGroup,
            // 'their_numbers': convo.number,
            'limit': limit,
            'offset': offset,
            // 'group_id': -2
          }, callback: (Map<String, dynamic> data) {
        List<SMSMessage> messages = [];
        if (data.containsKey("success") && !data["success"]) {
          return toast("${data['error']}");
        }
        for (Map<String, dynamic> item in data['items']) {
          //test getting a message SMSV2
          SMSMessage message = SMSMessage.fromV2(item);
          storeRecord(message);
          messages.add(message);
        }
        callback([...messages, ...failedMesages], true);
      });
    }
  }

  void deleteMessage(String messageId, String departmentId) {
    removeRecord(messageId);
    fusionConnection.apiV2Call(
        "post", "/messaging/message/${messageId}/${departmentId}/archive", {},
        callback: null);
  }

  offlineMessage(
      String text,
      SMSConversation conversation,
      String departmentId,
      XFile? mediaFile,
      Function? callback,
      Function largeMMSCallback,
      DateTime? schedule) {
    SMSMessage message = SMSMessage.offline(
      from: conversation.myNumber,
      to: conversation.number,
      isGroup: conversation.isGroup,
      text: text,
      user: fusionConnection.getExtension(),
      messageId: (int.parse(conversation.message!.id!) + 1).toString(),
      schedule: schedule != null ? schedule.toUtc().toString() : null,
    );
    conversation.message = message;
    storeRecord(message);
    fusionConnection.conversations.storeRecord(conversation);
  }

  Future<void> resendFailedMessage(SMSMessage message) async {
    this.removeRecord(message.id);
    await fusionConnection.db
        .delete('sms_message', where: 'id = ?', whereArgs: [message.id]);
  }
}
