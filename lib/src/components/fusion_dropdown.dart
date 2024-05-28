import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';

import '../styles.dart';
import 'popup_menu.dart';

class FusionDropdown extends StatefulWidget {
  final List<Widget>? children;
  final String? label;
  List<List<String>> options = [[]];
  final String? value;
  final TextStyle? style;
  final Function(String value) onChange;
  final Widget? button;
  List<SMSDepartment>? departments;
  final String selectedNumber;
  final Function(String value)? onNumberTap;
  final bool disabled;
  FusionDropdown(
      {Key? key,
      required this.onChange,
      this.button,
      this.children,
      this.label,
      this.value,
      this.style,
      required this.options,
      this.departments,
      required this.selectedNumber,
      this.onNumberTap,
      this.disabled = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _FusionDropdownState();
}

class _FusionDropdownState extends State<FusionDropdown> {
  List<Widget>? get _children => widget.children;

  String? get _label => widget.label;

  TextStyle? get _style => widget.style;

  List<List<String>> get _options => widget.options;

  String? get _value => widget.value;

  Function(String value) get _onChange => widget.onChange;

  Widget? get _button => widget.button;

  List<SMSDepartment>? get _allDepartments => widget.departments;

  String get _selectedNumber => widget.selectedNumber;

  Function(String value)? get _onNumberTap => widget.onNumberTap;

  bool get _disabled => widget.disabled;
  _dismissKeyboard() {
    FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
  }

  _bottomSheetOption(List option) {
    if (_allDepartments != null) {
      List<String> deptNUmbers = [];

      _allDepartments!.forEach((element) {
        if (element.id == option[1]) {
          deptNUmbers = element.numbers;
        }
      });

      return Container(
        decoration: BoxDecoration(
            color: option[1] == _value ? lightHighlight : Colors.transparent,
            border:
                Border(bottom: BorderSide(color: lightDivider, width: 1.0))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _onChange!(option[1]);
                Navigator.pop(context);
              },
              child: Row(children: [
                Container(
                  width: 220,
                  padding: EdgeInsets.only(bottom: 10, top: 14, left: 12),
                  child: Text(
                    option[0],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
            ),
            Column(
                children: deptNUmbers.map((String option) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _onNumberTap!(option);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                      // color: _selectedNumber == option
                      //     ? lightHighlight
                      //     : Colors.transparent,
                      ),
                  padding: EdgeInsets.only(
                      top: 12,
                      bottom: 12,
                      left: 12,
                      right: _selectedNumber == option ? 12 : 0),
                  child: Row(
                    children: [
                      Text(
                        option.formatPhone(),
                        style: TextStyle(
                            fontSize: 17,
                            color: _selectedNumber == option
                                ? Colors.white
                                : Colors.white70,
                            fontWeight: _selectedNumber == option
                                ? FontWeight.w700
                                : FontWeight.normal),
                      ),
                      Spacer(),
                      Visibility(
                        child: Image.asset("assets/icons/check_white.png",
                            height: 17, width: 17),
                        visible: _selectedNumber == option ? true : false,
                      ),
                    ],
                  ),
                ),
              );
            }).toList())
          ],
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          _onChange(option[1]);
          Navigator.pop(context);
        },
        child: Container(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
                color:
                    option[1] == _value ? lightHighlight : Colors.transparent,
                border: Border(
                    bottom: BorderSide(color: lightDivider, width: 1.0))),
            child: option.length > 3
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          if (option[3] == DepartmentIds.FusionChats)
                            Image.asset(
                              "assets/icons/messages/fusion_chats.png",
                              height: 24,
                            ),
                          if (option[3] == DepartmentIds.Personal)
                            Icon(
                              Icons.person,
                              color: personalChat,
                            ),
                          if (option[4] == DepartmentProtocols.telegram)
                            Image.asset(
                              "assets/icons/messages/telegram.png",
                              height: 24,
                            ),
                          if (option[4] == DepartmentProtocols.whatsapp)
                            Image.asset(
                              "assets/icons/messages/whatsapp.png",
                              height: 24,
                            ),
                          if (option[4] == DepartmentProtocols.facebook)
                            Image.asset(
                              "assets/icons/messages/messenger.png",
                              height: 24,
                            ),
                          if (int.parse(option[3]) > 0 && option[4] == "sms")
                            Image.asset(
                              "assets/icons/messages/department.png",
                              height: 24,
                            ),
                          LimitedBox(
                            maxWidth: MediaQuery.of(context).size.width - 230,
                            child: Text(option[0],
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          )
                        ],
                      ),
                      if (int.parse(option[2]) > 0)
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              shape: int.parse(option[2]) > 99
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              borderRadius: int.parse(option[2]) > 99
                                  ? BorderRadius.all(Radius.circular(20))
                                  : null,
                              color: crimsonDarker),
                          child: Text(
                            option[2],
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        )
                    ],
                  )
                : Text(option[0],
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700))),
      );
    }
  }

  _openPopup() {
    double maxHeight = MediaQuery.of(context).size.height * 0.5;
    double contentHeight = _options!.length * 60.0;
    if (contentHeight > 0 && contentHeight < maxHeight)
      maxHeight = contentHeight;

    _dismissKeyboard();

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (contact) => PopupMenu(
            label: _label,
            bottomChild: Container(
                constraints: BoxConstraints(
                    minHeight: 24,
                    minWidth: 90,
                    maxWidth: MediaQuery.of(context).size.width - 136,
                    maxHeight: _options.length > 1 ? maxHeight : 120),
                child: ListView(
                    padding: EdgeInsets.all(8),
                    children: _options.map((List<String> option) {
                      return Container(child: _bottomSheetOption(option));
                    }).toList()))));
  }

  @override
  Widget build(BuildContext context) {
    String? selected = this._value;
    for (List<String> opt in _options) {
      if (opt[1] == this._value) {
        selected = opt[0];
      }
    }

    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _disabled ? null : _openPopup,
        child: this._button != null
            ? this._button
            : Row(children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width - 250,
                  ),
                  child: Text(
                    selected == DepartmentIds.FusionChats
                        ? "Fusion Chats"
                        : selected == DepartmentIds.Unread
                            ? "Personal"
                            : selected!,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: _style != null ? _style : subHeaderTextStyle,
                  ),
                ),
                Container(
                  child:
                      Text(" " + mDash + " " + _selectedNumber!.formatPhone()),
                ),
                Container(
                    margin: EdgeInsets.only(left: 3, right: 12),
                    width: 10,
                    height: 5,
                    child: Image.asset("assets/icons/down_arrow.png",
                        height: 5, width: 10)),
              ]));
  }
}
