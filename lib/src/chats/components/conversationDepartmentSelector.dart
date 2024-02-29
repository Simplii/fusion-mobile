import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/conversation.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class DepartmentSelector extends StatelessWidget {
  final List<SMSDepartment> departments;
  final SMSConversation conversation;
  final ConversationVM conversationVM;
  const DepartmentSelector({
    required this.departments,
    required this.conversation,
    required this.conversationVM,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    List<List<String>> options = [];

    for (SMSDepartment department in departments) {
      if (department.id == DepartmentIds.AllMessages ||
          department.id == DepartmentIds.FusionChats) {
        continue;
      }
      options.add([department.groupName ?? "", department.id ?? ""]);
    }
    return Container(
      decoration: dropdownDecoration,
      padding: EdgeInsets.only(top: 0, bottom: 0, right: 0, left: 8),
      height: 36,
      child: FusionDropdown(
        disabled: false,
        departments: departments,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        value: conversationVM.conversationDepartmentId,
        selectedNumber: conversation.myNumber,
        options: options,
        onChange: (selectedDep) => print("change"),
        onNumberTap: (selectedNum) => print("change"),
        label: "All Departments",
      ),
    );
  }
}
