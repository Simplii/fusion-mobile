import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewConversationVM with ChangeNotifier {
  final FusionConnection fusionConnection;
  final Softphone? softphone;
  final SharedPreferences sharedPreferences;

  late String selectedDepartmentId;

  NewConversationVM({
    required this.fusionConnection,
    required this.softphone,
    required this.sharedPreferences,
  }) {
    selectedDepartmentId = sharedPreferences.getString("selectedGroupId") ??
        DepartmentIds.Personal;
  }

  String getMyNumber() {
    String myPhoneNumber = "";
    SMSDepartment department = fusionConnection.smsDepartments.getDepartment(
      selectedDepartmentId == DepartmentIds.AllMessages
          ? DepartmentIds.Personal
          : selectedDepartmentId,
    );
    print("MDBM dep ${department.serserialize()}");
    if (department.numbers.length > 0 &&
        department.id != DepartmentIds.AllMessages) {
      myPhoneNumber = department.numbers[0];
    }
    return myPhoneNumber;
  }

  void onDepartmentChange(String departmentId) {
    selectedDepartmentId = departmentId;
    notifyListeners();
  }

  void onNumberChange(String phoneNumber) {
    SMSDepartment? department =
        fusionConnection.smsDepartments.getDepartmentByPhoneNumber(phoneNumber);
    if (department != null) {
      selectedDepartmentId = department.id!;
      notifyListeners();
    }
  }
}
