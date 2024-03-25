import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/callpop/call_action_button.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/models/callpop_info.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:sip_ua/sip_ua.dart';

enum Views { Main, DialPad, Hold }

class IncomingWhileOnCall extends StatefulWidget {
  IncomingWhileOnCall({Key? key, this.softphone, this.call}) : super(key: key);

  final Softphone? softphone;
  final Call? call;

  @override
  State<StatefulWidget> createState() => _IncomingWhileOnCallState();
}

class _IncomingWhileOnCallState extends State<IncomingWhileOnCall> {
  Call? get call => widget.call;

  _hangupButton() {
    return GestureDetector(
      onTap: () {
        widget.softphone!.blockAndroidAudioEvents(500);
        widget.softphone!.hangUp(widget.call!);
      },
      child: Center(
          child: Container(
              decoration: raisedButtonBorder(crimsonLight,
                  darkenAmount: 40, lightenAmount: 60),
              padding: EdgeInsets.all(1),
              child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(50.0)),
                      color: crimsonLight),
                  child: Image.asset("assets/icons/phone_filled_white.png",
                      width: 24, height: 24)))),
    );
  }

  _answerButton() {
    return GestureDetector(
      onTap: () {
        widget.softphone!.blockAndroidAudioEvents(500);
        widget.softphone!.answerCall(widget.call);
      },
      child: Center(
          child: Container(
              decoration: raisedButtonBorder(successGreen,
                  darkenAmount: 40, lightenAmount: 60),
              padding: EdgeInsets.all(1),
              child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(50.0)),
                      color: successGreen),
                  child: Image.asset("assets/icons/call_view/phone_answer.png",
                      width: 28, height: 28)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    CallpopInfo? info = widget.softphone!.getCallpopInfo(widget.call!.id);

    Widget contents = Container(
        constraints: BoxConstraints(maxHeight: 180),
        padding: EdgeInsets.only(top: 42, bottom: 12),
        decoration: BoxDecoration(
            color: coal,
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16))),
        alignment: Alignment.center,
        child: Container(
            constraints: BoxConstraints(
                minWidth: 200,
                maxWidth: MediaQuery.of(context).size.width - 96),
            child: Column(children: [
              Row(
                children: [
                  ContactCircle.withDiameter(info != null ? info.contacts : [],
                      info != null ? info.crmContacts : [], 56),
                  Container(width: 0),
                  Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.softphone!.getCallerCompany(widget.call)!,
                            style: TextStyle(
                                fontSize: 12,
                                color: translucentWhite(0.66),
                                fontWeight: FontWeight.w700)),
                        Text(widget.softphone!.getCallerName(widget.call),
                            style: TextStyle(
                                fontSize: 24,
                                color: translucentWhite(1.0),
                                fontWeight: FontWeight.w700)),
                        Text(widget.softphone!.getCallerNumber(widget.call!),
                            style: TextStyle(
                                fontSize: 12,
                                color: translucentWhite(0.66),
                                fontWeight: FontWeight.w700)),
                      ])
                ],
              ),
              Container(height: 12),
              Row(children: [
                Spacer(),
                _hangupButton(),
                if (widget.softphone!.isIncoming(widget.call!)) Spacer(),
                if (widget.softphone!.isIncoming(widget.call!)) _answerButton(),
                Spacer()
              ])
            ])));

    return contents;
  }
}
