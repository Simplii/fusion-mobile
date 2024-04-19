import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:overlay_support/overlay_support.dart';

import 'fusion_model.dart';
import 'fusion_store.dart';

class DepartmentUnreadRecord extends FusionModel {
  int? departmentId;
  int? unread;
  String? inq;
  String? to;
  List<String> numbers = [];

  DepartmentUnreadRecord(Map<String, dynamic> obj) {
    List numbers = obj['numbers'] ?? [];
    this.departmentId = obj['id'];
    this.unread = obj['unread'];
    this.inq = obj['inq'];
    this.to = obj['to'];
    this.numbers = numbers.map((e) => e.toString()).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      "departmentId": this.departmentId,
      "unread": this.unread,
      "to": this.to,
      "numbers": this.numbers,
    };
  }
}

class UnreadsStore extends FusionStore<DepartmentUnreadRecord> {
  String id_field = "id";
  UnreadsStore(FusionConnection fusionConnection) : super(fusionConnection);

  getUnreads(Function(List<DepartmentUnreadRecord>, bool) callback) {
    fusionConnection.apiV2Call("get", "/messaging/unread", {},
        callback: (dynamic data) {
      if (data.runtimeType != List) {
        Map<String, dynamic> d = data;
        if (d.containsKey('error') && d['error'] == "invalid_login") {
          toast(
              "your account was logged out for some reason, please re-login, and report this issue to our team",
              duration: Duration(seconds: 5));
        } else {
          toast("there was an error trying to get unread messages",
              duration: Duration(seconds: 2));
        }
      } else {
        List<dynamic> datas = data;
        List<DepartmentUnreadRecord> response = [];
        clearRecords();
        List<SMSDepartment> allDeps =
            fusionConnection.smsDepartments.getRecords();
        SMSDepartment UnreadMessages =
            fusionConnection.smsDepartments.getDepartment(DepartmentIds.Unread);

        RegExp reg = RegExp(r'(^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$)');
        int allUnreads = 0;
        for (var dep in allDeps) {
          if (datas.isEmpty) {
            dep.unreadCount = 0;
          } else {
            int depUnreadCount = 0;
            for (var item in datas) {
              DepartmentUnreadRecord obj = DepartmentUnreadRecord(item);
              if (!obj.numbers.any((item) => reg.hasMatch(item))) {
                obj.departmentId = -3;
              }
              storeRecord(obj);

              if (dep.id == obj.departmentId.toString()) {
                response.add(obj);
                allUnreads += obj.unread!;
                depUnreadCount += obj.unread!;
              } else {
                dep.unreadCount = 0;
              }
            }
            if (dep.unreadCount != depUnreadCount) {
              dep.unreadCount = depUnreadCount;
            }
          }
          fusionConnection.smsDepartments.storeRecord(dep);
        }

        UnreadMessages.unreadCount = allUnreads;
        fusionConnection.smsDepartments.storeRecord(UnreadMessages);
        callback(response, true);
      }
    });
  }

  hasUnread() {
    List<DepartmentUnreadRecord> records = this.getRecords();
    int count = 0;
    for (DepartmentUnreadRecord record in records) {
      count += record.unread!;
    }
    return count > 0;
  }
}
