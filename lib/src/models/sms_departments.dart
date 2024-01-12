import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';

import 'carbon_date.dart';
import 'dids.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';

class SMSDepartment extends FusionModel {
  String? groupName;
  String? id;
  List<String> numbers = [];
  List<String> mmsNumbers = [];
  String? primaryUser;
  int? unreadCount;
  bool? usesDynamicOutbound;
  String? protocol;
  List<DepartmentUser> users = [];

  SMSDepartment(Map<String, dynamic> obj) {
    if (obj['id'].toString() == DepartmentIds.Personal) {
      id = DepartmentIds.Personal;
      groupName = "Personal";
      for (String n in obj['numbers']) {
        numbers.add(n);
      }
      unreadCount = obj['unread'];
      usesDynamicOutbound = false;
      primaryUser = null;
      if (obj.containsKey('mms_numbers')) {
        for (String n in obj['mms_numbers']) {
          mmsNumbers.add(n);
        }
      }
      protocol = "sms";
    } else {
      id = obj['id'].toString();
      groupName = obj['group_name'];
      for (String n in obj['numbers']) {
        numbers.add(n);
      }
      for (String n in obj['mms_numbers']) {
        mmsNumbers.add(n);
      }
      primaryUser = obj['primary_user'];
      unreadCount = obj['unread'];
      usesDynamicOutbound = obj['uses_dynamic_outbound'];
      protocol = obj['protocol'] ?? "sms";
      for (Map<String, dynamic> user in obj['users']) {
        users.add(DepartmentUser(
            id: user['id'],
            smsGroupId: user['sms_group_id'],
            uid: user['uid']));
      }
    }
  }

  serserialize() {
    return jsonEncode({
      'groupName': this.groupName,
      'id': this.id,
      'numbers': this.numbers,
      'mmsNumbers': mmsNumbers,
      'primaryUser': this.primaryUser,
      'unreadCount': this.unreadCount,
      'usesDynamicOutbound': this.usesDynamicOutbound,
      'protocol': this.protocol,
      'users': this.users
    });
  }

  Did toDid() {
    return Did({
      "to_user": "",
      "did": this.id,
      // "mmsCapable": false,
      "plan_description": "Dynamic Dialing",
      "groupName": this.groupName,
      "favorite": false
    });
  }

  String? getId() => this.id;
}

class SMSDepartmentsStore extends FusionStore<SMSDepartment> {
  String id_field = "id";
  SMSDepartmentsStore(FusionConnection fusionConnection)
      : super(fusionConnection);

  getDepartments(Function(List<SMSDepartment>) callback,
      {String username = ""}) async {
    List<SMSDepartment> deps = allDepartments();
    if (deps.isNotEmpty) {
      callback(deps);
    } else {
      await fusionConnection.apiV1Call("get", "/chat/my_groups", {},
          callback: (List<dynamic> datas) {
        String fusionChatsNumber =
            fusionConnection.getUid().toString().toLowerCase();
        fusionChatsNumber =
            fusionChatsNumber.isNotEmpty ? fusionChatsNumber : username;
        List<String> allNumbers = [fusionChatsNumber];
        List<String> allMMSNumbers = [];
        int allUnread = 0;

        for (Map<String, dynamic> data in datas) {
          allUnread += data['unread'] as int;
          for (String n in data['mms_numbers']) {
            allMMSNumbers.add(n);
          }
          for (String n in data['numbers']) {
            allNumbers.add(n);
          }
          storeRecord(SMSDepartment(data));
        }

        storeRecord(SMSDepartment({
          'id': DepartmentIds.AllMessages,
          'group_name': 'All Messages',
          'numbers': allNumbers,
          'mms_numbers': allMMSNumbers,
          'unread': allUnread,
          'uses_dynamic_outbound': false,
          'primary_user': null,
          'users': []
        }));

        storeRecord(SMSDepartment({
          'id': DepartmentIds.FusionChats,
          'group_name': 'Fusion Chats',
          'numbers': [fusionChatsNumber],
          'mms_numbers': [fusionChatsNumber],
          'unread': 0,
          'uses_dynamic_outbound': false,
          'primary_user': fusionConnection.getUid(),
          'protocol': DepartmentProtocols.FusionChats,
          'users': []
        }));

        callback(allDepartments());
      });
    }
  }

  getDepartment(String? id) {
    return lookupRecord(id);
  }

  List<SMSDepartment> allDepartments() {
    return getRecords();
  }

  SMSDepartment? getDepartmentByPhoneNumber(number) {
    List<SMSDepartment> departments = allDepartments();
    for (SMSDepartment dept in departments) {
      if (dept.numbers.contains(number) && dept.id != DepartmentIds.AllMessages)
        return dept;
    }
    return null;
  }
}

abstract class DepartmentIds {
  static const String Personal = "-1";
  static const String AllMessages = "-2";
  static const String FusionChats = "-3";
}

abstract class DepartmentProtocols {
  static const String FusionChats = "fusion-chats";
  static const String telegram = "telegram";
  static const String whatsapp = "whatsapp";
  static const String facebook = "facebook";
}

class DepartmentUser {
  final int id;
  final int smsGroupId;
  final String uid;
  DepartmentUser(
      {required this.id, required this.smsGroupId, required this.uid});

  toJson() {
    return {'id': this.id, 'sms_group_id': this.smsGroupId, 'uid': this.uid};
  }
}
