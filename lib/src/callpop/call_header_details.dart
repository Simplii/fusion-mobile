import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../styles.dart';

class CallHeaderDetails extends StatefulWidget {
  CallHeaderDetails(
      {Key? key,
      this.isRinging,
      this.callIsRecording,
      this.callerName,
      this.callerNumber,
      this.callRunTime,
      this.companyName,
      this.prefix})
      : super(key: key);

  final callerName;
  final companyName;
  final callerNumber;
  final callRunTime;
  final callIsRecording;
  final isRinging;
  final String? prefix;
  @override
  State<StatefulWidget> createState() => _CallHeaderDetailsState();
}

class _CallHeaderDetailsState extends State<CallHeaderDetails> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Padding(
              padding: EdgeInsets.only(left: 16.0, right: 16, top: 24, bottom: 16),
              child: Column(children: [
                Text(widget.companyName != "" ? widget.companyName : "",
                      style: TextStyle(
                          fontSize: 18,
                          height: 1.4,
                          color: translucentWhite(0.67),
                          fontWeight: FontWeight.w600)),
                Wrap(
                  alignment: WrapAlignment.center, children: [
                  Text(widget.callerName,
                      style: TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                  // Image.asset(
                  //   "assets/icons/call_view/edit.png",
                  //       width: 20, height: 20
                  // )
                ]),
                Text(widget.callerNumber,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: translucentWhite(0.67))),
                if (widget.prefix != "")
                  Text(widget.prefix!,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          color: translucentWhite(0.67))),
              ])),
          Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.callIsRecording)
                  Container(
                      margin: EdgeInsets.only(right: 8),
                      child: Image.asset(
                          "assets/icons/call_view/recording.png",
                          width: 13, height: 13
                      )
              ),

                if (!widget.isRinging)
                Text(widget.callRunTime,
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w700))
          ])
        ],
      ),
    );
  }
}
