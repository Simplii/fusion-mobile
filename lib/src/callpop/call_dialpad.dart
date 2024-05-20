import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_dtmf/dtmf.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/dialpad/dialpad_key.dart';
import 'package:sip_ua/sip_ua.dart';

import '../styles.dart';

class CallDialPad extends StatefulWidget {
  CallDialPad(this._softphone, this._activeCall, {Key? key}) : super(key: key);

  final Softphone? _softphone;
  final Call? _activeCall;

  @override
  State<StatefulWidget> createState() => _CallDialPadState();
}

class _CallDialPadState extends State<CallDialPad> {
  var dialedNumber = '';

  void handleDialPadKeyPress(String key) {
    setState(() {
      dialedNumber += key;
    });
    widget._softphone!.sendDtmf(widget._activeCall!, key, true);
    // Dtmf.playTone(digits: key, durationMs: 300);
  }

  void removeLastDigit() {
    if (dialedNumber.length == 0) return;

    setState(() {
      dialedNumber = dialedNumber.substring(0, dialedNumber.length - 1);
    });
  }

  var digitAlphas = [
    '',
    'ABC',
    'DEF',
    'GHI',
    'JKL',
    'MNO',
    'PQRS',
    'TUV',
    'WXYZ',
    '',
    '+',
    ''
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(
      children: [
        Container(
            alignment: Alignment.topCenter,
            padding: EdgeInsets.only(top: 0, bottom: 10),
            width: MediaQuery.of(context).size.width - 24,
            child: Stack(alignment: Alignment.centerRight, children: [
              Container(
                  height: 40,
                  alignment: Alignment.topCenter,
                  width: MediaQuery.of(context).size.width - 24,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    Container(
                        alignment: Alignment.topCenter,
                        width: MediaQuery.of(context).size.width - 24,
                        child: Text(dialedNumber,
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(fontSize: 36, color: Colors.white)))
                  ])),
              GestureDetector(
                  onTap: removeLastDigit,
                  child: Opacity(
                      opacity: 0.66,
                      child: Container(
                          decoration: clearBg(),
                          height: 22,
                          width: 40,
                          child: Container(
                              width: 22,
                              height: 16,
                              child: Image.asset(
                                  "assets/icons/call_view/backspace.png",
                                  width: 22,
                                  height: 16)))))
            ])),
        Container(
            height: 1,
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: translucentWhite(0.1494))),
        Container(
          child: Column(
            children: [
              Row(
                children: [
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '1',
                      alphas: digitAlphas[0]),
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '2',
                      alphas: digitAlphas[1]),
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '3',
                      alphas: digitAlphas[2]),
                ],
              ),
              Row(
                children: [
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '4',
                      alphas: digitAlphas[3]),
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '5',
                      alphas: digitAlphas[4]),
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '6',
                      alphas: digitAlphas[5]),
                ],
              ),
              Row(
                children: [
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '7',
                      alphas: digitAlphas[6]),
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '8',
                      alphas: digitAlphas[7]),
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '9',
                      alphas: digitAlphas[8]),
                ],
              ),
              Row(
                children: [
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '*',
                      alphas: digitAlphas[9]),
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '0',
                      alphas: digitAlphas[10]),
                  DialPadKey(
                      onPressed: handleDialPadKeyPress,
                      digit: '#',
                      alphas: digitAlphas[11]),
                ],
              ),
            ],
          ),
        )
      ],
    ));
  }
}
