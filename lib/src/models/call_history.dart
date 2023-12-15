import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/phone_contact.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'contact.dart';
import 'coworkers.dart';
import 'crm_contact.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';
import '../utils.dart';

class CallHistory extends FusionModel {
  String id;
  DateTime startTime;
  String toDid;
  String fromDid;
  String to;
  String from;
  int duration;
  String recordingUrl;
  Coworker coworker;
  Contact contact;
  CrmContact crmContact;
  bool missed;
  String direction;
  String callerId;
  String cdrIdHash;
  PhoneContact phoneContact;

  isInternal(String domain) {
    if (to.length < 10) return false;
    if (direction == 'inbound')
      return to.substring(to.length - domain.length)
          .toLowerCase() == domain.toLowerCase();
    else
      return from.substring(from.length - domain.length)
          .toLowerCase() == domain.toLowerCase();
  }

  getOtherNumber(String domain) {
    return isInternal(domain) && to != "abandoned"
        ? (direction == "inbound" ? fromDid : toDid).toString()
        : (direction == "inbound" ? from : to).toString();
  }

  CallHistory(Map<String, dynamic> obj) {
    id = obj['id'].toString();
    startTime = DateTime.parse(obj['startTime']).toLocal();
    toDid = obj['toDid'];
    fromDid = obj['fromDid'];
    to = obj['to'];
    from = obj['from'];
    duration = obj['duration'];
    recordingUrl = obj['recordingUrl'];
    direction = obj['direction'];
    callerId = obj['callerId'];
    if (direction == 'Incoming') {
      direction = 'inbound';
    } else if (direction == 'Outgoing') {
      direction = 'outbound';
    }

    if (obj['lead'] != null && obj['lead'].runtimeType != bool) {
      crmContact = CrmContact.fromExpanded(obj['lead']);
    }
    if (obj['contact'] != null && obj['contact'].runtimeType != bool) {
      contact = Contact(obj['contact']);
    }

    if (obj['contacts'] != null) {
      List list = obj['contacts'];
      if (list.length > 0) {
        contact = Contact.fromV2(list[0]);
      }
    }
    // missed = obj['to'] == "abandoned";
    if(obj.containsKey('coworker') && obj['coworker'] != null){
      Map<String,dynamic> data = jsonDecode(obj['coworker']);
      data['id'] = data['uid'];
      coworker = Coworker.fromV2(data);
    }
    cdrIdHash = obj['cdrIdHash'].toString();
    missed = obj['missed'].runtimeType == String 
      ? obj['missed'] == 'true'? true : false 
      : obj['missed'];
    if(obj.containsKey('phoneContact') && obj['phoneContact'] != null){
       Map<String,dynamic> data = jsonDecode(obj['phoneContact']);
      phoneContact = PhoneContact(data);
    }
  } 
  
  serialize(){
    return{
      "id": id.toString(),
      "cdrIdHash": cdrIdHash.toString(),
      "startTime": startTime,
      "toDid": toDid,
      "fromDid": fromDid,
      "to": to,
      "from": from,
      "duration": duration,
      "recordingUrl": recordingUrl,
      "direction": direction,
      "callerId": callerId,
      "contact": contact,
      "missed": missed,
      "coworker": coworker,
      "phoneContact": phoneContact
    };
  }
  isInbound() {
    return direction == "inbound";
  }

  @override
  String getId() => this.id.toString();
}

class CallHistoryStore extends FusionStore<CallHistory> {
  String id_field = "id";
  CallHistoryStore(FusionConnection fusionConnection) : super(fusionConnection);

 @override
  storeRecord(CallHistory record) {
    super.storeRecord(record);
    persist(record);
  }

  persist(CallHistory record) {
    fusionConnection.db.insert('call_history', 
        {
        'id': record.getId(),
        'cdrIdHash': record.cdrIdHash,
        'startTime': record.startTime.toString(),
        'toDid': record.toDid,
        'fromDid': record.fromDid,
        'to': record.to,
        'from': record.from,
        'duration': record.duration,
        'recordingUrl': record.recordingUrl ?? "",
        'direction': record.direction,
        'callerId': record.callerId,
        // 'crmContact': record?.crmContact?.serialize() ?? null,
        'contacts': record?.contact?.serialize() ?? null,
        'coworker': record?.coworker?.serialize() ?? null,
        'missed' : record.missed.toString(),
        'phoneContact': record?.phoneContact?.serialize() ?? null
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  getPersisted(
    int limit, int offset,
    Function(List<CallHistory>, bool, bool) callback) {
    getDatabasesPath().then((path){
      openDatabase(join(path,"fusion.db")).then((db) {
        db.query(
          'call_history',
          limit: limit,
          offset: offset,
        ).then((List<Map<String, dynamic>> results) {
          List<CallHistory> list = [];
          for (Map<String, dynamic> result in results) {
            Map<String,dynamic> copy = {...result};
            copy['contacts']  = result['contacts'] != null 
              ? [jsonDecode(result['contacts'])] 
              : null;
            list.add(CallHistory(copy));
          }
          callback(list, false, true);
        });
      });
    });
  }

  getRecentHistory(int limit, int offset,bool pullToRefresh,
      Function(List<CallHistory>, bool, bool) callback) async {
    List<CallHistory> stored = getRecords();
    if(stored.isEmpty && !pullToRefresh) {
      // app just oppened
      // load coworkers store since recent call screen loads first before coworkers in postLogin
      await fusionConnection.auth();
      fusionConnection.coworkers.getCoworkers((c) {});
      getPersisted(limit,offset,callback);
    }

    if(stored.isNotEmpty && !pullToRefresh){
      callback(stored, false, false);
    } 
    
    final PermissionStatus status = await Permission.contacts.status;
    List<PhoneContact> phoneContacts = [];
    if(status.isGranted){
      phoneContacts = await fusionConnection.phoneContacts.getAdderssBookContacts("");
    }

    await fusionConnection.apiV2Call(
      "get", "/calls/recent", {
        'limit': limit, 
        'offset': offset,
      },
      callback: (Map<String, dynamic> datas) {
        List<CallHistory> response = [];
        if(datas.containsKey('items')){
          for (Map<String, dynamic> item in datas['items']) {
            CallHistory obj = CallHistory(item);
            if(obj.cdrIdHash != "0"){
              // backend returning an empty callHistory obj when there are no
              // calls 
              obj.coworker = fusionConnection.coworkers
                  .lookupCoworker(obj.direction == 'inbound' ? obj.from : obj.to);
              if(phoneContacts.isNotEmpty){
                for (PhoneContact phoneContact in phoneContacts) {
                  List<String> numbers = 
                    phoneContact.phoneNumbers.map((e) => e["number"]).toList().cast<String>();
                  if(obj.isInbound() && numbers.contains(obj.fromDid)){
                    obj.phoneContact = phoneContact;
                  } else if(!obj.isInbound() && numbers.contains(obj.toDid)){
                    obj.phoneContact = phoneContact;
                  }
                }
              }
              storeRecord(obj);
              response.add(obj);
            }
          }
        }

        callback(response, true, false);
      },
      onError: () => print("MyDebugMessage failed 5 retries recent_calls")
    );
  }
}