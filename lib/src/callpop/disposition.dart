import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/disposition.dart';
import 'package:fusion_mobile_revamped/src/models/disposition.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:sip_ua/sip_ua.dart';

class DispositionView extends StatefulWidget {
  final Call terminatedCall;
  final Softphone? softphone;
  final FusionConnection? fusionConnection;
  final Function onDone;
  const DispositionView({
    required this.terminatedCall, 
    required this.softphone, 
    required this.fusionConnection,
    required this.onDone,
    Key? key
  }) : super(key: key);

  @override
  State<DispositionView> createState() => _DispositionViewState();
}

class _DispositionViewState extends State<DispositionView> {
  Call get _terminatedCall => widget.terminatedCall;
  FusionConnection? get _fusionConnection => widget.fusionConnection;
  Softphone? get _softphone => widget.softphone;
  Function get _onDone => widget.onDone;

  @override
  Widget build(BuildContext context) {
    String? phoneNumber = _softphone!.getCallerNumber(_terminatedCall);
    
    return Scaffold(
      backgroundColor: smoke.withOpacity(0.33),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.7), BlendMode.dstATop),
              image: _softphone!.getCallerPic(_terminatedCall),
              fit: BoxFit.cover)),
        child: SafeArea(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 21, sigmaY: 21),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DispositionListView(
                key: GlobalKey(),
                fromCallView: false,
                fusionConnection: _fusionConnection,
                onDone: _onDone,
                softphone: _softphone,
                call: _terminatedCall,
                phoneNumber: phoneNumber,)),
          ),
        ),
      ),
    );
  }
}