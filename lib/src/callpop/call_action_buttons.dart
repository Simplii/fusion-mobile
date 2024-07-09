import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/callpop/call_action_button.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';

enum Views { Main, DialPad, Hold }

class CallActionButtons extends StatefulWidget {
  CallActionButtons({
    Key? key,
    this.dialPadOpen,
    this.callIsMuted,
    this.setDialpad,
    this.actions,
    this.isIncoming,
    this.isRinging,
    this.callIsRecording,
    this.isMergeDisabled,
    this.callOnHold,
    this.resumeDisabled,
    this.loading,
    this.currentAudioSource = "Phone",
  }) : super(key: key);

  final Map<String, Function()>? actions;
  final bool? isMergeDisabled;
  final bool? isIncoming;
  final bool? isRinging;
  final bool? callOnHold;
  final bool? callIsRecording;
  final bool? dialPadOpen;
  final bool? callIsMuted;
  final bool? resumeDisabled;
  final bool? loading;
  Function(bool)? setDialpad;
  String currentAudioSource;
  @override
  State<StatefulWidget> createState() => _CallActionButtonsState();
}

class _CallActionButtonsState extends State<CallActionButtons> {
  bool? get dialPadOpen => widget.dialPadOpen;
  bool? get _loading => widget.loading;
  Softphone? _softphone = Softphone.instance;
  String get _currentAudioSource => widget.currentAudioSource;

  Widget _getMainView(bool onHold) {
    return Container(
        key: ValueKey<int>(2),
        width: MediaQuery.of(context).size.width,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (onHold)
                  CallActionButton(
                      onPressed: widget.actions!['onResumeBtnPress'],
                      title: 'Resume',
                      icon: Image.asset("assets/icons/call_view/play.png",
                          width: 24, height: 24),
                      disabled: widget.resumeDisabled)
                else
                  CallActionButton(
                      onPressed: widget.actions!['onHoldBtnPress'],
                      title: 'Hold',
                      disabled: _softphone?.confCreated == true,
                      icon: Image.asset("assets/icons/call_view/hold.png",
                          width: 24, height: 24)),
                CallActionButton(
                    onPressed: widget.actions!['onXferBtnPress'],
                    title: 'Xfer',
                    disabled: _softphone?.confCreated == true,
                    icon: Image.asset("assets/icons/call_view/transfer.png",
                        width: 24, height: 24)),
                CallActionButton(
                    onPressed: () {
                      widget.actions!['onDialBtnPress']!();
                    },
                    title: 'Dial',
                    icon: Image.asset("assets/icons/call_view/dialpad.png",
                        width: 24, height: 24)),
                CallActionButton(
                    onPressed: widget.actions!['onParkBtnPress'],
                    title: 'Park',
                    disabled: _softphone?.confCreated == true,
                    icon: Image.asset("assets/icons/call_view/park.png",
                        width: 24, height: 24)),
                CallActionButton(
                    onPressed: widget.actions!['onConfBtnPress'],
                    title: _softphone?.confCreated == true
                        ? "3 Way"
                        : _softphone?.activeCall != null &&
                                _softphone?.calls.length == 1
                            ? 'Add'
                            : 'Merge',
                    icon: _softphone?.mergingCalls == true
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ))
                        : _softphone?.confCreated == true
                            ? LimitedBox(
                                maxHeight: 24,
                                child: Icon(
                                  Icons.groups,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              )
                            : _softphone?.activeCall != null &&
                                    _softphone?.calls.length == 1
                                ? Image.asset(
                                    "assets/icons/call_view/conference.png",
                                    width: 24,
                                    height: 24)
                                : Image.asset(
                                    "assets/icons/call_view/merge.png",
                                    width: 24,
                                    height: 24),
                    disabled: _softphone?.activeCall == null ||
                        _softphone?.confCreated == true),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                CallActionButton(
                    onPressed: widget.actions!['onRecBtnPress'],
                    title: 'Rec',
                    icon: Image.asset(
                        widget.callIsRecording!
                            ? "assets/icons/call_view/rec_stop.png"
                            : "assets/icons/call_view/rec.png",
                        width: 24,
                        height: 24),
                    disabled: onHold),
                CallActionButton(
                    onPressed: widget.actions!['onMuteBtnPress'],
                    title: widget.callIsMuted! ? 'Unmute' : 'Mute',
                    icon: Image.asset(
                        widget.callIsMuted!
                            ? "assets/icons/muted.png"
                            : "assets/icons/notmuted.png",
                        width: 24,
                        height: 24)),
                Expanded(child: _hangupButton()),
                CallActionButton(
                    onPressed: widget.actions!['onTextBtnPress'],
                    title: 'Text',
                    disabled: _softphone?.confCreated == true,
                    icon: _loading!
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ))
                        : Image.asset("assets/icons/call_view/chattext.png",
                            width: 24, height: 24)),
                CallActionButton(
                    onPressed: widget.actions!['onAudioBtnPress'],
                    title: 'Audio',
                    icon: _currentAudioOutput()),
              ],
            )
          ],
        ));
  }

  Widget _currentAudioOutput() {
    IconData icon = Icons.volume_down;
    if (_currentAudioSource == "Bluetooth") {
      icon = Icons.bluetooth;
    }
    if (_currentAudioSource == "Speaker") {
      icon = Icons.volume_up;
    }
    return Icon(icon, size: 28, color: Colors.white);
  }

  _hangupButton() {
    return GestureDetector(
      onTap: widget.actions!['onHangup'],
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
                  child: Image.asset("assets/icons/call_view/phone.png",
                      width: 28, height: 28)))),
    );
  }

  _answerButton() {
    return GestureDetector(
      onTap: widget.actions!['onAnswer'],
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

  Widget _restrictedView() {
    return Container(
        key: ValueKey<int>(1),
        constraints: BoxConstraints(minHeight: 82, maxHeight: 82),
        width: MediaQuery.of(context).size.width,
        child: Column(children: [
          Spacer(),
          Container(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Spacer(flex: 3),
                Container(
                    child: _hangupButton(), margin: EdgeInsets.only(bottom: 8)),
                if (widget.isRinging! && widget.isIncoming!) Spacer(flex: 1),
                if (widget.isRinging! && widget.isIncoming!)
                  Container(
                      child: _answerButton(),
                      margin: EdgeInsets.only(bottom: 8)),
                if (widget.isRinging!) Spacer(flex: 2),
                if (!widget.dialPadOpen!)
                  CallActionButton(
                      onPressed: widget.actions!['onAudioBtnPress'],
                      title: '',
                      icon: Image.asset(
                          widget.callIsMuted!
                              ? "assets/icons/call_view/audio_muted.png"
                              : "assets/icons/call_view/audio.png",
                          width: 24,
                          height: 24)),
                if (!widget.isRinging!)
                  Expanded(
                      flex: 3,
                      child: GestureDetector(
                          onTap: () {
                            widget.setDialpad!(false);
                          },
                          child: Container(
                              alignment: Alignment.center,
                              decoration: clearBg(),
                              child: Text('Hide',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16)))))
              ],
            ),
          )
        ]));
  }

  Widget _getView() {
    if (widget.isRinging!) {
      return _restrictedView();
    }
    if (widget.callOnHold!) {
      return _getMainView(true);
    } else if (widget.dialPadOpen!) {
      return _restrictedView();
    } else {
      return _getMainView(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget contents = Container(
      constraints: BoxConstraints(minHeight: widget.isRinging! ? 104 : 160),
      child: AnimatedContainer(
        height: widget.isRinging! || widget.dialPadOpen! ? 82 : 154,
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.only(top: 12, bottom: 10),
        decoration: BoxDecoration(
            color: widget.callOnHold! || widget.dialPadOpen!
                ? Colors.transparent
                : coal.withAlpha((255 * 0.7).round()),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8), topRight: Radius.circular(8))),
        child: AnimatedSwitcher(
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
              return Stack(
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
                alignment: Alignment.bottomCenter,
              );
            },
            switchInCurve: Curves.easeIn,
            switchOutCurve: Curves.easeOut,
            duration: Duration(milliseconds: 200),
            child: _getView()),
      ),
    );

    double sigma = (widget.callOnHold! || widget.dialPadOpen!) ? 6.0 : 0.0;

    return ClipRect(
        child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: contents));
  }
}
