import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class ConversationsListViewHeader extends StatelessWidget {
  final ChatsVM chatsVM;
  const ConversationsListViewHeader({
    required this.chatsVM,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 0, left: 24, right: 0, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 30,
            margin: EdgeInsets.only(top: 16),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 90,
            ),
            child: Text(
              chatsVM.selectedDepartmentName(),
              style: headerTextStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          FusionDropdown(
            selectedNumber: "",
            onChange: chatsVM.onGroupChange,
            value: chatsVM.selectedDepartmentId,
            options: chatsVM.groupOptions(),
            label: "Select a Department",
            button: Stack(children: [
              Container(
                margin: EdgeInsets.only(right: 24, top: 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: translucentSmoke,
                ),
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.expand_more,
                  size: 30,
                ),
              ),
              if (chatsVM.selectedDepartmentId != DepartmentIds.AllMessages)
                Positioned(
                  right: 19,
                  top: 11,
                  child: Container(
                    constraints: BoxConstraints(minWidth: 20, maxHeight: 20),
                    decoration: BoxDecoration(
                        color: crimsonLight,
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Center(
                          child: LimitedBox(
                        maxWidth: 28,
                        child: Text("12",
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      )),
                    ),
                  ),
                ),
            ]),
          )
        ],
      ),
    );
  }
}
