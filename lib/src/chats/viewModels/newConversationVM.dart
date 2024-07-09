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
  late List<SMSDepartment>? allDepartments;
  NewConversationVM({
    required this.fusionConnection,
    required this.softphone,
    required this.sharedPreferences,
  }) {
    selectedDepartmentId = sharedPreferences.getString("selectedGroupId") ??
        DepartmentIds.Personal;
    allDepartments = fusionConnection.smsDepartments.getRecords();
  }

  String _getDepartmentWithNumbers({bool getMyPhoneNumber = false}) {
    String ret = "";

    SMSDepartment? departmentWithNumbers = allDepartments
        ?.where((element) =>
            element.numbers.isNotEmpty &&
            element.id != DepartmentIds.Unread &&
            element.id != DepartmentIds.AllMessages &&
            element.id != DepartmentIds.FusionChats)
        .firstOrNull;

    SMSDepartment fusionChats = fusionConnection.smsDepartments
        .getDepartment(DepartmentIds.FusionChats);

    if (getMyPhoneNumber) {
      ret = departmentWithNumbers != null
          ? departmentWithNumbers.numbers.first
          : fusionChats.numbers.first;
    } else {
      ret = departmentWithNumbers != null
          ? departmentWithNumbers.id
          : fusionChats.id;
    }

    return ret;
  }

  String getMyNumber() {
    String myPhoneNumber = "";
    SMSDepartment department = fusionConnection.smsDepartments.getDepartment(
      selectedDepartmentId == DepartmentIds.AllMessages ||
              selectedDepartmentId == DepartmentIds.Unread
          ? DepartmentIds.Personal
          : selectedDepartmentId,
    );
    if (department.numbers.isEmpty && department.id == DepartmentIds.Personal) {
      myPhoneNumber = _getDepartmentWithNumbers(getMyPhoneNumber: true);
    } else if (department.numbers.isNotEmpty &&
        department.id != DepartmentIds.AllMessages &&
        department.id != DepartmentIds.Unread) {
      myPhoneNumber = department.numbers[0];
    }
    return myPhoneNumber;
  }

  String getSelectedDepartment() {
    String departmentId = selectedDepartmentId == DepartmentIds.AllMessages
        ? DepartmentIds.Personal
        : selectedDepartmentId;
    SMSDepartment selectedDepartment =
        fusionConnection.smsDepartments.getDepartment(departmentId);

    if (selectedDepartment.numbers.isEmpty) {
      departmentId = _getDepartmentWithNumbers();
    }
    return departmentId;
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
