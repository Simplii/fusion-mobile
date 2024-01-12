import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class CallActionButton extends StatefulWidget {
  CallActionButton(
      {Key? key, this.onPressed, this.title, this.icon, this.disabled})
      : super(key: key);

  final VoidCallback? onPressed;
  final String? title;
  final Widget? icon;
  final bool? disabled;

  @override
  State<StatefulWidget> createState() => _CallActionButtonState();
}

class _CallActionButtonState extends State<CallActionButton> {
  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: GestureDetector(
      onTap: () {
        if (widget.disabled != true) {
          widget.onPressed!();
        }
      },
      child: Container(
        padding: EdgeInsets.only(top: 12, left: 8, right: 8),
        decoration: clearBg(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
                opacity: widget.disabled == true ? 0.5 : 1.0,
                child: widget.icon),
            Container(
                margin: EdgeInsets.only(top: 6, bottom: 10),
                child: Text(widget.title!.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        height: 1.4,
                        fontWeight: FontWeight.w800,
                        color: Color.fromARGB(127, 255, 255, 255))))
          ],
        ),
      ),
    ));
  }
}
