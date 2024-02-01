import 'package:flutter/services.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:sip_ua/src/rtc_session.dart';
import 'package:sip_ua/src/ua.dart';

class LnSession extends RTCSession {
  LnSession(UA? ua) : super(ua);
}


class LnCall extends Call {
  late RTCSession _session;

  RTCSession get session => _session;
  CallStateEnum state = CallStateEnum.NONE;
  late String remote_identity;
  late String remote_display_name;
  late String direction;

  late String uuid;
  late MethodChannel nativeChannel;

  LnCall(
    String id, 
    RTCSession session, 
    CallStateEnum state
  ) : super(id, session, state);
  LnCall.makeLnCall(String callId, String? remoteAddress): super(callId, LnSession(null), CallStateEnum.NONE);

  setIdentities(number, callerid, direction) {
    remote_identity = number;
    remote_display_name = callerid;
    this.direction = direction;
  }

  setChannel(channel, uuid) {
    this.uuid = uuid;
    nativeChannel = channel;
  }

  setHold(bool hold) {
    nativeChannel!.invokeMethod("lpSetHold", [uuid, hold]);
  }

  sendDTMF(String digits, [Map<String, dynamic>? arg]) {
    nativeChannel!.invokeMethod("lpSendDtmf", [uuid, digits]);
  }

  hold() {
    setHold(true);
  }

  unhold() {
    setHold(false);
  }

  answer(Map<String, dynamic> s, {mediaStream = null}) {
    print("answer call here");
    print(uuid);
    nativeChannel.invokeMethod("lpAnswer", [uuid]);
  }
  hangup([Map<String, dynamic>? x = null]) {
    nativeChannel!.invokeMethod("lpEndCall", [uuid]);
  }

  mute([bool? x, bool? y]) {
    nativeChannel!.invokeMethod("lpMuteCall", [uuid]);
  }
  unmute([bool? x, bool? y]) {
    nativeChannel!.invokeMethod("lpUnmuteCall", [uuid]);
  }

  refer(String destination) {
    nativeChannel!.invokeMethod("lpRefer", [uuid, destination]);
  }

  void setState(CallState newState) {print("1");
    state = newState.state;print("2");
  }
}