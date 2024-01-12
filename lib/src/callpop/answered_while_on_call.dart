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

class AnsweredWhileOnCall extends StatefulWidget {
  AnsweredWhileOnCall({Key? key,required this.activeCall, this.softphone, this.calls})
      : super(key: key);

  final Softphone? softphone;
  final List<Call>? calls;
  final Call activeCall;

  @override
  State<StatefulWidget> createState() => _AnsweredWhileOnCallState();
}

class _AnsweredWhileOnCallState extends State<AnsweredWhileOnCall> {
  List<Call>? get calls => widget.calls;

  Call get activeCall => widget.activeCall;

  Softphone? get softphone => widget.softphone;

  switchGestureDetector(Widget child, call) {
    return GestureDetector(
        onTap: () {
          softphone!.makeActiveCall(call);
        },
        child: Container(decoration: clearBg(), child: child));
  }

  _callRow(Call call) {
    CallpopInfo? info = softphone!.getCallpopInfo(call.id);
    TextStyle textStyle = TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white);
    bool isMerged = softphone!.isCallMerged(call);

    return switchGestureDetector(
        Padding(
          padding: const EdgeInsets.only(top:4.0),
          child: Row(children: [

            ContactCircle.withDiameterAndMargin(info != null ? info.contacts : [],
                info != null ? info.crmContacts : [], 24, 8),

            Text(softphone!.getCallerName(call), style: textStyle),
            Expanded(child: switchGestureDetector(Container(), call)),
            if (softphone!.getHoldState(call)) Text("Hold", style: textStyle),
            Text(" " + mDash + " " + softphone!.getCallRunTimeString(call),
                style: textStyle),
            if (!isMerged &&
                false) // disabing until we can support conference calling
              GestureDetector(
                  onTap: () {
                    softphone!.mergeCalls(activeCall, call);
                  },
                  child: Container(
                      decoration: clearBg(),
                      padding: EdgeInsets.only(left: 12, top: 2, bottom: 2),
                      child: Image.asset("assets/icons/call_view/merge.png",
                          width: 20, height: 20))),
            Container(width: 12,),
            _hangupButton(call)
          ]),
        ),
        call);
  }

  _hangupButton(call) {
    return GestureDetector(
      onTap: () {
        widget.softphone!.hangUp(call);
      },
      child: Center(
          child: Container(
              decoration: raisedButtonBorder(crimsonLight,
                  darkenAmount: 40, lightenAmount: 60),
              padding: EdgeInsets.all(1),
              child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(50.0)),
                      color: crimsonLight),
                  child: Image.asset("assets/icons/phone.png",
                      width: 14, height: 14)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
          height: 45 + 0 + calls!.length * 37.0,
          padding: EdgeInsets.only(top: 42, bottom: 0),
          decoration: BoxDecoration(
              color: coal,
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16))),
          alignment: Alignment.center,
          child: Container(
              padding: EdgeInsets.only(left: 12, right: 12, bottom: 12),
              child: Column(
                  children: calls!
                      .map((Call c) => _callRow(c))
                      .toList()
                      .cast<Widget>()))),
      if(softphone!.assistedTransferInit &&  activeCall.state == CallStateEnum.STREAM)
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () {
              Call newCall =
                  calls!.where((call) => call.id != activeCall!.id).first;
              softphone!.completeAssistedTransfer(activeCall,newCall);
            },
            child: Container(
              margin: EdgeInsets.only(right: 15, top: 10),
              alignment: Alignment.centerRight,
              decoration: BoxDecoration(
                  color: bgBlend,
                  borderRadius: BorderRadius.all(Radius.circular(6))),
              padding: EdgeInsets.all(10),
              child: Column(children: [
                Image.asset(
                  "assets/icons/call_view/merge.png",
                  width: 28,
                  height: 28,
                ),
                Padding(
                  padding: const EdgeInsets.only(top:5),
                  child: Text(
                    'Complete',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                )
              ]),
            ),
          )
        ],
      )
    ]);
  }
}
