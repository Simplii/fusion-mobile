import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'contact.dart';
import 'coworkers.dart';
import 'crm_contact.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';
import 'messages.dart';

class CallLog {
  DateTime? startTime;
  DateTime? endTime;
  int? duration;
  String? type;
  late String to;
  late String from;
  String? recording;
  String? note;
  String? disposition;
}

class TimelineItem extends FusionModel {
  String? id;
  DateTime? time;
  late String phoneNumber;
  String type = "";
  SMSMessage? message;
  late CallLog callLog;

  TimelineItem(Map<String, dynamic> obj) {
      time = obj.containsKey('time')
        ? DateTime.parse(obj['time']['date']).toLocal()
        : (obj.containsKey('time_start')
        ? DateTime.fromMillisecondsSinceEpoch(int.parse(obj['time_start']) * 1000)
        : DateTime.fromMillisecondsSinceEpoch(0));
    type = obj.containsKey('recording')
        ? 'call'
        : (obj.containsKey('converted_mms') ? 'message' : '');
    id = type + ':' + obj['id'].toString();

    if (type == 'message') {
      // test time line messages SMSV2
      message = SMSMessage.fromV2(obj);
    }
    else {
      callLog = CallLog();
      callLog.startTime = time;
      if (obj['time_end'] != null)
        callLog.endTime = DateTime.fromMillisecondsSinceEpoch(int.parse(obj['time_end'].toString()) * 1000);
      else
        callLog.endTime = time;
      callLog.duration = int.parse(obj['length']);
      callLog.type = obj['type'];
      callLog.from = obj['from'];
      callLog.to = obj['to'];
      callLog.recording = obj['recording'].runtimeType == String ? obj['recording'] : null;
      callLog.note = obj['note'];
      callLog.disposition = obj['disposition'].runtimeType == String ? obj['disposition'] : null;
      if (callLog.note == '')
        callLog.note = null;
      if (callLog.type == 'Outgoing')
        phoneNumber = obj['to_did'];
      else
        phoneNumber = obj['from_did'];
    }
  }

  TimelineItem.fromV2(Map<String, dynamic> obj, String myUser) {
    type = obj["type"];

      if (type == 'message') {
        Map<String, dynamic> messageObj = obj['object'];
        messageObj['fromMe'] = messageObj['user'].toString().toLowerCase() == myUser.toLowerCase();
        message = SMSMessage.fromV2(messageObj);
        time = DateTime.parse(messageObj['time']);
      }
      else if (type == 'call'){
        Map<String, dynamic> callObj = obj['object'];
        callLog = CallLog();
        callLog.startTime = DateTime.parse(callObj['startTime']);
        time = callLog.startTime;
        if (callObj['duration'] != null)
          callLog.endTime = DateTime.fromMillisecondsSinceEpoch(
            callLog.startTime!.millisecondsSinceEpoch + (callObj['duration'] * 1000) as int);
        else
          callLog.endTime = time;
        callLog.duration = callObj['duration'];
        callLog.type = callObj['direction'];
        callLog.from = callObj['from'];
        callLog.to = callObj['to'];
        callLog.recording =
        callObj['recordingUrl'].runtimeType == String ? callObj['recordingUrl'] : null;
        callLog.note = callObj['notes'] != null ? callObj['notes'] : '';
        callLog.disposition =
        callObj['disposition'].runtimeType == String ? callObj['disposition'] : null;
        if (callLog.note == '')
          callLog.note = null;
        if (callLog.type == 'Outgoing')
          phoneNumber = callObj['toDid'];
        else
          phoneNumber = callObj['fromDid'];
      }
    }

  @override
  String? getId() => this.id;
}

class TimelineItemStore extends FusionStore<TimelineItem> {
  String id_field = "id";
  TimelineItemStore(FusionConnection fusionConnection) : super(fusionConnection);

  getTimeline(int contactId,
      Function(List<TimelineItem>, bool) callback) {
    print("willookuptmeline");
    fusionConnection.apiV1Call(
        "get",
        "/contacts/" + contactId.toString() + "/timeline",
        {},
        callback: (List<dynamic> datas) {
          print("lookeduptimeline");
          print(datas);
          List<TimelineItem> response = [];

          for (Map<String, dynamic> item in datas) {
            try {
              //TimelineItem obj = TimelineItem.fromV2(item, fusionConnection.getUid());
              TimelineItem obj = TimelineItem(item);
              if (obj.type == 'message')
                obj.phoneNumber =
                (obj.message!.domain == fusionConnection.getDomain()
                    ? obj.message!.to : obj.message!.from);
              storeRecord(obj);
              response.add(obj);
            } catch (e) {
              print("failedhere");
              print(item);
            }
          }

          callback(response, true);
        });
  }


  getTimelineFromNumbers(List<String> numbers,
      Function(List<TimelineItem>?, bool) callback) {
    callback(getRecords()
        .where((TimelineItem item) => numbers.contains(item.phoneNumber))
        .toList()
        .cast<TimelineItem>(), false);

    fusionConnection.apiV1Call(
        "post",
        "/contacts/timeline",
        {'numbers': numbers},
        callback: (List<dynamic> datas) {
          List<TimelineItem> response = [];

          for (Map<String, dynamic> item in datas) {
            try {
              TimelineItem obj = TimelineItem(item);
              if (obj.type == 'message')
                obj.phoneNumber =
                (obj.message!.domain == fusionConnection.getDomain()
                    ? obj.message!.to : obj.message!.from);
              storeRecord(obj);
              response.add(obj);
            } catch (e) {
              print("failed timeline here");
              print(item);
            }
          }

          callback(response, true);
        });
  }
}