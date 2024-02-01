import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

class DialPadKey extends StatefulWidget {
  DialPadKey({Key? key,required this.onPressed, this.digit, this.alphas})
      : super(key: key);

  final Function(String) onPressed;
  final digit;
  final alphas;

  @override
  State<StatefulWidget> createState() => _DialPadKeyState();
}

class _DialPadKeyState extends State<DialPadKey> {
  var digitStyling = TextStyle(color: particle, fontSize: 32.0, height: 1.0);
  var alphaStyling = TextStyle(color: smoke, height: 1.0);

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: TextButton(
            style: TextButton.styleFrom(
              shape: CircleBorder(),
              padding: EdgeInsets.all(8),
            ),
            onPressed: () {
              widget.onPressed(widget.digit.toString());
            },
            child: Container(
                decoration: clearBg(),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          // margin: EdgeInsets.only(bottom: 2),
                          child: Text(widget.digit, style: digitStyling)),
                      Container(
                          // margin: EdgeInsets.only(bottom: 10),
                          child: Text(widget.alphas, style: alphaStyling))
                    ]))));
  }
}
