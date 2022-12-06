import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' as Aps;
import 'package:callkeep/callkeep.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_phone_state/flutter_phone_state.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_sip_ua_helper.dart';
import 'package:fusion_mobile_revamped/src/backend/ln_call.dart';
import 'package:fusion_mobile_revamped/src/models/callpop_info.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:ringtone_player/ringtone_player.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter_audio_manager/flutter_audio_manager.dart';
import '../../main.dart';
import '../utils.dart';
import 'fusion_connection.dart';
import 'package:flutter_incall_manager/flutter_incall_manager.dart';
//import 'package:bluetoothadapter/bluetoothadapter.dart';
import 'package:uuid/uuid.dart';

class Softphone implements SipUaHelperListener {
  String outputDevice = "Phone";
  MediaStream _localStream;
  MediaStream _remoteStream;
  final FusionSIPUAHelper helper = FusionSIPUAHelper();
  List<Function> _listeners = [];
  bool interrupted = false;
  BuildContext _context;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      registerNotifications();

  bool _isUsingUa = false;
  MethodChannel _callKit;
  MethodChannel _telecom;
  MethodChannel _android;

  IncallManager incallManager = new IncallManager();

  bool registered = false;
  bool connected = false;
  bool _settingupcallkeep = false;
  String couldGetAudioSession = "";

  FlutterCallkeep _callKeep;
  Map<String, Map<String, dynamic>> callData = {};
  List<Call> calls = [];
  Call activeCall;
  String _awaitingCall = "none";
  Map<String, int> _tempUUIDs = {};
  final FusionConnection _fusionConnection;
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  bool _savedOutput = false;
  Aps.AudioPlayer _playingAudio;
  bool isCellPhoneCallActive = false;
  //AudioSession _audioSession;
  bool _isAudioSessionActive = false;
  bool _attemptingToRegainAudio = false;
  bool _ringingInbound = false;

  String defaultInput = "";
  String defaultOutput = "";
  bool echoLimiterEnabled = false;
  bool echoCancellationEnabled = false;
  String echoCancellationFilterName = "";
  bool isTestingEcho = false;
  Function _onUnregister = null;
  List<String> callIdsAnswered = [];
  //IncallManager incallManager = new IncallManager();

  final Aps.AudioCache _audioCache = Aps.AudioCache(
    fixedPlayer: Aps.AudioPlayer()..setReleaseMode(Aps.ReleaseMode.LOOP),
  );
  final _outboundAudioPath = "audio/outgoing.wav";
  final _callWaitingAudioPath = "audio/call_waiting .wav";
  final _inboundAudioPath = "audio/inbound.mp3";
  Aps.AudioPlayer _outboundPlayer;
  Aps.AudioPlayer _inboundPlayer;
  bool _blockingEvent = false;

  //Bluetoothadapter flutterbluetoothadapter = Bluetoothadapter();
  StreamSubscription _btConnectionStatusListener, _btReceivedMessageListener;
  String btConnectionStatus = "NONE";
  String btReceivedMessage;

  // List<BtDevice> devices = [];
  String _savedLogin;
  String _savedAor;
  String _savedPassword;
  List<List<String>> devicesList = [];

  Softphone(this._fusionConnection) {
    if (Platform.isIOS)
      _callKit = MethodChannel('net.fusioncomm.ios/callkit');
    else if (Platform.isAndroid) {
      _android = MethodChannel('net.fusioncomm.android/calling');
      _telecom = MethodChannel('net.fusioncomm.android/telecom');
    }

    _audioCache.load(_outboundAudioPath);
    _audioCache.load(_inboundAudioPath);

    _initBluetooth();
  }

  _initBluetooth() {
    /*  flutterbluetoothadapter
        .initBlutoothConnection(Uuid().toString());
    flutterbluetoothadapter.initBlutoothConnection(Uuid().toString());
    print("initing bluetooth");
    flutterbluetoothadapter
        .checkBluetooth()
        .then((value) => print("bluetooth value: " + value.toString()));
    _btConnectionStatusListener =
        flutterbluetoothadapter.connectionStatus().listen((dynamic status) {
      btConnectionStatus = status.toString();
      _updateListeners();
      print("bluetooth: " + btConnectionStatus + " : " + btReceivedMessage);
    });
    _btReceivedMessageListener =
        flutterbluetoothadapter.receiveMessages().listen((dynamic newMessage) {
      btReceivedMessage = newMessage.toString();
      _updateListeners();
      print("bluetooth msg: " + btConnectionStatus + " : " + btReceivedMessage);
    });
    flutterbluetoothadapter.startServer();*/
  }

  close() async {
    try {
      // helper.unregister(true);
      await helper.stop();
      //helper.terminateSessions({});
    } catch (e) {
      print("error closing");
    }
  }

  _checkAudio() {
    var shouldPlayOutbound = (activeCall.direction == "OUTGOING" &&
        (activeCall.state == CallStateEnum.CONNECTING ||
            activeCall.state == CallStateEnum.PROGRESS));

    if (!shouldPlayOutbound && _outboundPlayer != null) {
      stopOutbound();
    }
  }

  _playAudio(String path, bool ignore) {
    print("willplayaudio");
    if (Platform.isIOS && path == _outboundAudioPath) {
      Aps.AudioCache cache = Aps.AudioCache();
      if (_outboundPlayer == null) {
        print("setupoutbound");
        _outboundPlayer = Aps.AudioPlayer();
        cache.loop(_outboundAudioPath).then((Aps.AudioPlayer playing) {
          _outboundPlayer = playing;
          _outboundPlayer.earpieceOrSpeakersToggle();
        });
      }
    } else if (Platform.isAndroid) {
      Aps.AudioCache cache = Aps.AudioCache();
      if (path == _outboundAudioPath) {
        return true;
        if (_outboundPlayer == null) {
          _outboundPlayer = Aps.AudioPlayer();
          cache.loop(_outboundAudioPath).then((Aps.AudioPlayer playing) {
            _outboundPlayer = playing;
            _outboundPlayer.earpieceOrSpeakersToggle();
            print("set outbound player");
          });
        }
      } else if (path == _inboundAudioPath) {
        if (!(calls.length > 1 &&
            activeCall.state != CallStateEnum.CONNECTING &&
            activeCall.state != CallStateEnum.PROGRESS)) {
          _ringingInbound = true;
          FlutterAudioManager.changeToSpeaker();
          RingtonePlayer.ringtone(
              alarmMeta: AlarmMeta("net.fusioncomm.android.MainActivity",
                  "ic_alarm_notification",
                  contentTitle: "Phone Call", contentText: "IncomingPhoneCall"),
              volume: 1.0);
        } else {
          _inboundPlayer = Aps.AudioPlayer();
          cache.loop(_callWaitingAudioPath).then((Aps.AudioPlayer playing) {
            _inboundPlayer = playing;
            _inboundPlayer.earpieceOrSpeakersToggle();
          });
        }
      }
    }
  }

  _attemptToRegainAudioSession() async {
    return;
    _attemptingToRegainAudio = true;
    try {
      await _callKit.invokeMethod('attemptAudioSessionActive');
    } on PlatformException catch (e) {
      print("error callkit invoke attempt audio session");
    }
    var future = new Future.delayed(const Duration(milliseconds: 10000), () {
      if (couldGetAudioSession != "") {
        _attemptToRegainAudioSession();
      } else {
        _attemptingToRegainAudio = false;
      }
    });
  }

  stopOutbound() {
    if (_outboundPlayer != null) {
      _outboundPlayer.stop();
      _outboundPlayer.release();
    }
  }

  stopInbound() {
    print("stopinbound");
    _ringingInbound = false;
    RingtonePlayer.stop();
  }

  setContext(BuildContext context) {
    _context = context;
    setup();
  }

  setup() {
    setupPermissions();

    if (Platform.isIOS)
      _setupCallKit();
    else if (Platform.isAndroid) {
      _callKeep = FlutterCallkeep();
      _setupCallKeep();
      _android.setMethodCallHandler(_callKitHandler);

      FlutterPhoneState.rawPhoneEvents.forEach((element) {
        print("rawphonevent");
        print(element.type);
        print(element);
        if (element.type == RawEventType.connected &&
            activeCall != null &&
            !_blockingEvent) {
          isCellPhoneCallActive = true;
          activeCall.hold();
        } else if (element.type == RawEventType.disconnected) {
          isCellPhoneCallActive = false;
        }
      });
    }
  }

  _setupTelecom() {
    _telecom.setMethodCallHandler(_telecomHandler);
  }

  Future<dynamic> _telecomHandler(MethodCall methodCall) async {
    print("telecommessage:" + methodCall.method);
    switch (methodCall.method) {
      case 'setPushToken':
        String token = methodCall.arguments[0] as String;
        _fusionConnection.setPushkitToken(token);
        return;
    }
  }

  _setupCallKit() {
    _callKit.setMethodCallHandler(_callKitHandler);
  }

  _setupCallKeep() {
    _callKeep.on(
        CallKeepDidDisplayIncomingCall(), _callKeepDidDisplayIncomingCall);
    _callKeep.on(CallKeepPerformAnswerCallAction(), _callKeepAnswerCall);
    _callKeep.on(CallKeepDidPerformDTMFAction(), _callKeepDTMFPerformed);
    _callKeep.on(CallKeepDidToggleHoldAction(), _callKeepDidToggleHold);
    _callKeep.on(
        CallKeepDidPerformSetMutedCallAction(), _callKeepDidPerformSetMuted);
    _callKeep.on(CallKeepPerformEndCallAction(), _callKeepPerformEndCall);
    _callKeep.on(CallKeepPushKitToken(), _callKeepPushkitToken);

    final callSetup = <String, dynamic>{
      'ios': {
        'appName': 'Fusion Mobile',
      },
      'android': {
        'alertTitle': 'Permissions required',
        'alertDescription':
            'This application needs to access your phone accounts',
        'cancelButton': 'Cancel',
        'okButton': 'ok',
        'foregroundService': {
          'channelId': 'net.fusioncomm.android',
          'channelName': 'Foreground service for my app',
          'notificationTitle': 'My app is running on background',
          'notificationIcon': 'Path to the resource icon of the notification',
        },
      },
    };

    if (!_settingupcallkeep) {
      _settingupcallkeep = true;
      _callKeep.setup(_context, callSetup);
    }

    if (Platform.isAndroid) {
      //if (isIOS) iOS_Permission();
      //_firebaseMessaging.requestNotificationPermissions();
      print("audiofocusaddlistener");

      /*incallManager.onAudioFocusChange.stream.listen((event) {
        print("audiofocuschange");
        print(event);
      });*/

      FirebaseMessaging.instance.getToken().then((token) {
        print('[FCM] token => ' + token);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification notification = message.notification;
      });
    }
  }

  void _setLpCallState(LnCall call, CallStateEnum stateEnum) {
    print("setting state");
    print(stateEnum.name);
    CallState state = CallState(stateEnum);
    print("setstateoncall");
    print(state);
    print(state.state);
    call.setState(state);
    print("fwding state");
    callStateChanged(call, state);
    print("done");
  }

  setDefaultInput(String deviceId) {
    print("heresetit");
    _android.invokeMethod("lpSetDefaultInput", [deviceId]);
    defaultInput = deviceId;
    _updateListeners();
  }

  setDefaultOutput(String deviceId) {
    print("setdefaultoutput");
    _android.invokeMethod("lpSetDefaultOutput", [deviceId]);
    defaultOutput = deviceId;
    _updateListeners();
  }

  Future<dynamic> _callKitHandler(MethodCall methodCall) async {
    //  Sentry.captureMessage("callkitmethod:" + methodCall.method);
    print("callkitmethod:" + methodCall.method);
    print(methodCall);
    print("themethod: '" + methodCall.method + "'");
    var args = methodCall.arguments;
    print(args);
    if (Platform.isAndroid) {
      switch (methodCall.method) {
        case "lnNewDevicesList":
          if (Platform.isAndroid) {
            var decoded = json.decode(args['devicesList']);
            devicesList = [];
            for (dynamic item in decoded) {
              print(item);
              devicesList.add([item[0], item[1], item[2]]);
            }
            defaultInput = args['defaultInput'];
            defaultOutput = args['defaultOutput'] as String;
            echoLimiterEnabled = args['echoLimiterEnabled'] as bool;
            echoCancellationEnabled = args['echoCancellationEnabled'] as bool;
            echoCancellationFilterName =
                args['echoCancellationFilterName'] as String;
            args = [
              args['devicesList'] as String,
              args["defaultInput"] as String,
              args["defaultOutput"] as String
            ];
          }
          break;
        case "lnOutgoingInit":
          args = [args['uuid'], args['callId'], args['remoteAddress']];
          break;
        case "lnIncomingReceived":
          args = [
            args['callId'],
            args['remoteContact'],
            args['remoteAddress'],
            args['uuid'],
            args['displayName']
          ];
          break;
        default:
          args = [args['uuid']];
      }
    } else {
      if (methodCall.method == "lnNewDevicesList") {
        print("newdeviceslist");
        print(args);
        devicesList = [];
        var decoded = json.decode(args[0] as String);
        for (dynamic item in decoded) {
          print("onedeviceitem");
          print(item);
          devicesList.add([item[0], item[1], item[2]]);
        }
        print("updatedeeviceslist");
        print(devicesList);
        defaultInput = args[4] as String;
        defaultOutput = args[5] as String;
        echoLimiterEnabled = args[1] as bool;
        echoCancellationEnabled = args[2] as bool;
        echoCancellationFilterName = args[3] as String;
      }
    }
    print("gotargs");
    print(args);
    print("switchnow");
    switch (methodCall.method) {
      case "lnOutgoingInit":
        _addCall(_linkLnCallWithUuid(
            _cleanToAddress(args[2]), args[1], args[0], args[2], "OUTGOING"));
        break;
      case "lnOutgoingProgress":
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.PROGRESS);
        break;
      case "lnOutgoingRinging":
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.PROGRESS);
        // [uuid]
        break;
      case "lnCallConnected":
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.CONFIRMED);
        break;
      case "lnCallStreamsRunning":
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.STREAM);
        break;
      case "lnCallPaused":
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.HOLD);
        break;
      case "lnConnected":
      case "lnCallConnected":
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.CONFIRMED);
        break;
      case "lnStreamsRunning":
      case "lnCallStreamsRunning":
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.STREAM);
        break;
      case "lnPaused":
      case "lnCallPaused":
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.HOLD);
        break;
      case "lnPausedByRemote":
      case "lnCallPausedByRemote":
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.HOLD);
        break;
      case "lnCallUpdatedByRemote":
        //        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.PROGRESS);
        break;

      case "lnReleased":
      case "lnCallReleased":
        print("released call");
        print(args[0]);
        print(_getCallByUuid(args[0]));
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.ENDED);
        break;
      case "lnIncomingReceived":
        print("processincoming");
        print(args[2]);
        print(args[0]);
        print(args[3]);
        print("callerid");
        print(args[4]);
        var toAddress = args[2] as String;
        toAddress = _cleanToAddress(toAddress);
        var callerId = args[4] as String;

        LnCall call = _linkLnCallWithUuid(toAddress, args[0] as String,
            args[3] as String, callerId, "INCOMING");
        print("incoming");
        print(call);
        _addCall(call);
        break;
      case "lnError":
      case "lnCallError":
        _setLpCallState(_getCallByUuid(args[0]), CallStateEnum.FAILED);
        break;
      case "lnAudioDeviceChanged":
        //this fires when changing output device IOS only
        final newSelectedDeviceIsBlue =
            RegExp(r'(AU Bluetooth capture, playback:).*').hasMatch(args[0]);
        final newSelectedDeviceIsSpeaker =
            RegExp(r'(AU Speaker:).*').hasMatch(args[0]);
        this.defaultOutput = args[0];
        this.outputDevice = newSelectedDeviceIsBlue
            ? 'Bluetooth'
            : newSelectedDeviceIsSpeaker
                ? 'Speaker'
                : 'Phone';
        _updateListeners();
        break;
      case "lnAudioDeviceListUpdated":
        // []
        break;
      case "lnNewDevicesList":
        /*      print("newdevicesList");
        print(devicesList);
        print(args[0]);
        print(args);
        List<List<String>> devices = args[0];
        print(devices);
        devicesList = devices;
        defaultInput = args[1];
        defaultOutput = args[2];
        print(defaultInput);
        print(defaultOutput);*/
        switchToHeadsetWhenConnected();
        break;
      case "lnRegistrationOk":
        registrationStateChanged(
            RegistrationState(state: RegistrationStateEnum.REGISTERED));
        break;
      case "lnRegistrationCleared":
        registrationStateChanged(
            RegistrationState(state: RegistrationStateEnum.UNREGISTERED));
        break;
      case 'setPushToken':
        String token = methodCall.arguments[0] as String;
        _fusionConnection.setPushkitToken(token);
        return;

      case 'setAudioSessionActive':
        return;

      case 'answerButtonPressed':
        String callUuid = methodCall.arguments[0] as String;
        callIdsAnswered.add(callUuid);
        print("ansewrbuttonpressed");
        print(callUuid);
        print(_getCallByUuid(callUuid));
        if (_getCallByUuid(callUuid) == null &&
            (activeCall.state == CallStateEnum.CONNECTING ||
                activeCall.state == CallStateEnum.PROGRESS)) {
          callData[activeCall.id]['uuid'] = callUuid;
          print("newuuid");
          print(_getCallByUuid(callUuid));
        }

        answerCall(_getCallByUuid(callUuid));
        return;

      case 'endButtonPressed':
        String callUuid = methodCall.arguments[0] as String;
        hangUp(_getCallByUuid(callUuid));
        return;

      case 'holdButtonPressed':
        String callUuid = methodCall.arguments[0] as String;
        bool isHold = methodCall.arguments[1] as bool;
        setHold(_getCallByUuid(callUuid), isHold, false);
        return;

      case 'muteButtonPressed':
        String callUuid = methodCall.arguments[0] as String;
        bool isMute = methodCall.arguments[1] as bool;
        setMute(_getCallByUuid(callUuid), isMute, false);
        return;

      case 'dtmfPressed':
        String callUuid = methodCall.arguments[0] as String;
        String digits = methodCall.arguments[1] as String;
        sendDtmf(_getCallByUuid(callUuid), digits, false);
        return;

      case 'startCall':
        String callUuid = methodCall.arguments[0] as String;
        String callerId = methodCall.arguments[0] as String;
        String callerName = methodCall.arguments[0] as String;

        bool callIdFound = false;
        for (Map<String, dynamic> data in callData.values) {
          if (data.containsKey('uuid') && data['uuid'] == callUuid) {
            callIdFound = true;
          }
        }

        if (!callIdFound) {
          int time = DateTime.now().millisecondsSinceEpoch;
          bool matched = false;
          for (String tempUUID in _tempUUIDs.keys) {
            if (time - _tempUUIDs[tempUUID] < 10 * 1000) {
              _replaceTempUUID(tempUUID, callUuid);
              matched = debugInstrumentationEnabled;
            }
          }
          if (!matched) {
            _awaitingCall = callUuid;
          }
        }

        return;

      default:
        throw MissingPluginException('notImplemented');
    }
  }

  register(String login, String password, String aor) {
    registerLinphone(login, password, aor);
  }

  _getMethodChannel() {
    return (Platform.isIOS ? _callKit : _android);
  }

  registerLinphone(String login, String password, String aor) {
    print("iosreg");
    print(aor.split("@"));
    _savedLogin = login;
    _savedPassword = password;
    _savedAor = aor;
    _getMethodChannel().invokeMethod(
        "lpRegister", [aor.split("@")[0], password, aor.split("@")[1]]);
  }

  _unregisterLinphone() {
    print("iosunreg");
    _getMethodChannel().invokeMethod("lpUnregister", []);
  }

  _cleanToAddress(toAddress) {
    toAddress = toAddress
        .replaceFirst(RegExp(r".*<sip:"), "")
        .replaceFirst(RegExp(">.*"), "")
        .replaceFirst(RegExp(r"@.*$"), "");
    toAddress = toAddress.replaceFirst(RegExp(r"<.*?> *$"), "");
    if (toAddress.length == 12 && toAddress[0] == "+" && toAddress[1] == "1") {
      toAddress = toAddress.substring(2);
    }
    return toAddress.replaceFirst('sip:', '');
  }

  registerAndroid(String login, String password, String aor) {
    UaSettings settings = UaSettings();

    settings.webSocketSettings.allowBadCertificate = true;
    settings.webSocketUrl = "ws://mobile-proxy.fusioncomm.net:8080";

    if (aor == "9812fm@Simplii1" || aor == "9811fm@Simplii1") {
      print("using test push proxy 9811/9812 detected");
      settings.webSocketUrl = "ws://mobile-proxy.fusioncomm.net:9002";
    }

    settings.uri = aor;
    settings.authorizationUser = login;
    settings.password = password;
    settings.displayName = aor;

    settings.userAgent = 'Fusion Mobile - Dart';
    settings.dtmfMode = DtmfMode.RFC2833;
    if (Platform.isIOS) {
      settings.iceGatheringTimeout = 500;
    } else if (Platform.isAndroid) {
      settings.iceGatheringTimeout = 1000;
    }
    settings.iceServers = [
//      {"urls": "stun:stun.l.google.com:19302"},
      {"urls": "stun:services.fusioncomm.net:3478"},
      {
        "urls": "turn:services.fusioncomm.net:3478",
        "username": "fuser",
        "credential": "fpassword"
      }
    ];

    helper.start(settings);
    helper.addSipUaHelperListener(this);
  }

  reregister() {
    print("reregistering...");
    registerLinphone(_savedLogin, _savedPassword, _savedAor);
  }

  setupPermissions() {
    FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: true,
        provisional: false,
        sound: true);

    FirebaseMessaging.instance.getToken().then((String key) {
      print("firebase token - " + key);
    });
  }

  makeCall(String destination) async {
    doMakeCall(destination);
  }

  doMakeCall(String destination) async {
    _playAudio(_outboundAudioPath, false);

    if (!destination.contains("sip:")) destination = "sip:" + destination;
    if (!destination.contains("@"))
      destination += "@" + _fusionConnection.getDomain();

    _getMethodChannel().invokeMethod("lpStartCall", [destination]);
  }

  makeActiveCall(Call call) {
    if (Platform.isAndroid && activeCall == null) {
      print("audioincallmanager.start");
    }
    if (Platform.isAndroid) {
      incallManager.start(auto: true, media: MediaType.AUDIO);
    }
    activeCall = call;
    if (Platform.isAndroid) {
      _callKeep.setCurrentCallActive(_uuidFor(call));
    }
    call.unmute();
    call.unhold();
    print(call.id);
    print(call.direction);
    print("making active callkit call:" + call.id + ":" + call.direction);

    if (_getCallDataValue(call.id, "isReported") != true &&
        call.direction == "OUTGOING") {
      if (Platform.isIOS) {
        print("reportoing outging call callkit");
        _setCallDataValue(call.id, "isReported", true);
        _getMethodChannel().invokeMethod("reportOutgoingCall",
            [_uuidFor(call), getCallerNumber(call), getCallerName(call)]);
      }
    }

    for (Call c in calls) {
      if (c.id != call.id) {
        print("setholdonothercall");
        setHold(c, true, false);
      }
    }
  }

  _setApiIds(call, termId, origId) {
    _setCallDataValue(call.id, "apiTermId", termId);
    _setCallDataValue(call.id, "apiOrigId", origId);
  }

  _callHasApiIds(call) {
    return _getCallDataValue(call.id, "apiTermId") != null;
  }

  Map<String, String> _getCallApiIds(call) {
    return {
      "term": _getCallDataValue(call.id, "apiTermId"),
      "orig": _getCallDataValue(call.id, "apiOrigId")
    };
  }

  checkCallIds(Map<String, dynamic> message) {
    if (message.containsKey('term_id')) {
      for (Call call in calls) {
        if (!_callHasApiIds(call)) {
          if ((message["term_id"] as String).onlyNumbers() ==
                  ("" + getCallerNumber(call)).onlyNumbers() ||
              (message["orig_id"] as String).onlyNumbers() ==
                  ("" + getCallerNumber(call)).onlyNumbers() ||
              (message["term_sub"] as String).onlyNumbers() ==
                  ("" + getCallerNumber(call)).onlyNumbers() ||
              (message["orig_own_sub"] as String).onlyNumbers() ==
                  ("" + getCallerNumber(call)).onlyNumbers()) {
            _setApiIds(call, message['term_callid'], message['orig_callid']);
            return;
          }
        }
      }
    }
  }

  sendDtmf(Call call, String tone, bool fromUi) {
    if (Platform.isAndroid && fromUi) {
      _callKeep.sendDTMF(_uuidFor(call), tone);
    }
    call.sendDTMF(tone);
  }

  isStreamConnected() {
    return _localStream != null;
  }

  registrationState() {
    return helper.registerState.state;
  }

  registrationError() {
    return helper.registerState.cause;
  }

  isRegistered() {
    return helper.registered;
  }

  setSpeaker(bool useSpeaker) {
    _savedOutput = useSpeaker;

    print("lpsetspeaker");
    _getMethodChannel().invokeMethod("lpSetSpeaker", [useSpeaker]);

    this.outputDevice = 'Speaker';
    this._updateListeners();
  }

  setEarpiece(bool useEarpiece) {
    _savedOutput = useEarpiece;

    print("lpsetspeaker $defaultInput");
    _getMethodChannel().invokeMethod("lpSetSpeaker", [false]);

    this.outputDevice = 'Phone';
    this._updateListeners();
  }

  setBluetooth(bool isBluetooth) {
    _savedOutput = isBluetooth;
    _getMethodChannel().invokeMethod("lpSetBluetooth");
    // need to set defalut output device setDefaultOutput()
    this.outputDevice = 'Bluetooth';
    this._updateListeners();
  }

  isSpeakerEnabled() {
    return this.outputDevice == 'Speaker';
  }

  setHold(Call call, bool setOnHold, bool fromUi) async {
    _setCallDataValue(call.id, "onHold", setOnHold);

    if (fromUi) {
      if (setOnHold) {
        if (Platform.isAndroid) {
          _callKeep.setOnHold(_uuidFor(call), true);
          _getMethodChannel().invokeMethod("lpSetHold", [_uuidFor(call), true]);
        }
        print("setholdindart");
        call.hold();
        _getMethodChannel().invokeMethod("setHold", [_uuidFor(call)]);
      } else {
        if (Platform.isAndroid) {
          _callKeep.setOnHold(_uuidFor(call), false);
          _getMethodChannel()
              .invokeMethod("lpSetHold", [_uuidFor(call), false]);
        }
        print("setholdinvoke");
        _getMethodChannel().invokeMethod("setUnhold", [_uuidFor(call)]);
      }
    } else if (setOnHold) {
      call.hold();
    } else {
      call.unhold();
    }
  }

  setMute(Call call, bool setMute, bool fromUi) {
    if (setMute) {
      _setCallDataValue(call.id, "muted", true);
      call.mute();
      if (Platform.isAndroid && fromUi) {
        _callKeep.setMutedCall(_uuidFor(call), true);
      }
      if (fromUi) {
        _getMethodChannel().invokeMethod('muteCall', [_uuidFor(call)]);
      }
    } else {
      _setCallDataValue(call.id, "muted", false);
      call.unmute();
      if (Platform.isAndroid && fromUi) {
        _callKeep.setMutedCall(_uuidFor(call), false);
      }
      if (fromUi) {
        _getMethodChannel().invokeMethod('unMuteCall', [_uuidFor(call)]);
      }
    }
  }

  getMuted(Call call) {
    return _getCallDataValue(call.id, "muted", def: false);
  }

  isIncoming(Call call) {
    return call.direction == 'INCOMING';
  }

  isConnected(Call call) {
    return _getCallDataValue(call.id, "answerTime") != null;
  }

  transfer(Call call, String destination) {
    call.refer(destination);
    _removeCall(call);
  }

  hangUp(Call call) {
    try {
      call.hangup();
    } catch (e) {}
    _removeCall(call);
  }

  answerCall(Call call) async {
    if (call == null) {
      print("return, null");
      return;
    } else if (_getCallDataValue(call.id, "answerTime") != null) {
      print("skipping, answertime");
      print(call.id);
      print(_getCallDataValue(call.id, "answerTime") != null);
    } else {
      if (callIdsAnswered.contains(_uuidFor(call))) {
        callIdsAnswered.remove(_uuidFor(call));
      }
      if (_isUsingUa) {
        final mediaConstraints = <String, dynamic>{
          'audio': true,
          'video': false
        };
        MediaStream mediaStream;
        print("building stream to answer");
        print("answering call now");
        print(mediaStream);
        try {
          mediaStream =
              await navigator.mediaDevices.getUserMedia(mediaConstraints);
        } catch (e) {
          toast("unable to connect to microphone, check permissions");
          print("unable to connect");
        }
        call.answer(helper.buildCallOptions(), mediaStream: mediaStream);
        if (Platform.isAndroid) {
          //
          _callKeep.answerIncomingCall(_uuidFor(call));
        }
      } else {
        call.answer({});
        if (Platform.isAndroid) {
          _callKeep.answerIncomingCall(_uuidFor(call));
        }
      }
      makeActiveCall(call);
      _setCallDataValue(call.id, "answerTime", DateTime.now());

      if (Platform.isAndroid) {
        flutterLocalNotificationsPlugin.cancel(intIdForString(call.id));
        flutterLocalNotificationsPlugin
            .cancel(intIdForString(_getCallDataValue(call.id, "apiTermId")));
        flutterLocalNotificationsPlugin.cancelAll();
      } else if (Platform.isIOS) {
        _callKit.invokeMethod("answerCall", [_uuidFor(call)]);
      }
    }
  }

  backToForeground() {
    _callKeep.backToForeground();
  }

  Future<void> handleIncomingCall(String uuid) async {
    Call call = _getCallByUuid(uuid);
    String contactName = getCallerName(call);
  }

  _callKeepDidDisplayIncomingCall(CallKeepDidDisplayIncomingCall event) {
    String callUuid = event.callUUID;
    bool callIdFound = false;
    for (Map<String, dynamic> data in callData.values) {
      if (data.containsKey('uuid') && data['uuid'] == callUuid) {
        callIdFound = true;
      }
    }

    if (!callIdFound) {
      int time = DateTime.now().millisecondsSinceEpoch;
      bool matched = false;
      for (String tempUUID in _tempUUIDs.keys) {
        if (time - _tempUUIDs[tempUUID] < 10 * 1000) {
          _replaceTempUUID(tempUUID, callUuid);
          matched = debugInstrumentationEnabled;
        }
      }
      if (!matched) {
        _awaitingCall = callUuid;
      }
    }
  }

  _replaceTempUUID(String tempUuid, String callKeepUuid) {
    _tempUUIDs.remove(tempUuid);
    bool matched = false;
    for (Map<String, dynamic> data in callData.values) {
      if (data['uuid'] == tempUuid) {
        data['uuid'] = callKeepUuid;
      }
    }
  }

  _callKeepDTMFPerformed(CallKeepDidPerformDTMFAction event) {
    sendDtmf(_getCallByUuid(event.callUUID), event.digits, false);
  }

  _callKeepAnswerCall(CallKeepPerformAnswerCallAction event) {
    Call call = _getCallByUuid(event.callUUID);
    answerCall(call);
  }

  _callKeepDidReceiveStartCall(CallKeepDidReceiveStartCallAction event) {}

  _callKeepDidPerformSetMuted(CallKeepDidPerformSetMutedCallAction event) {
    setMute(_getCallByUuid(event.callUUID), event.muted, false);
  }

  _callKeepDidToggleHold(CallKeepDidToggleHoldAction event) {
    setHold(_getCallByUuid(event.callUUID), event.hold, false);
  }

  _callKeepPerformEndCall(CallKeepPerformEndCallAction event) {
    //  hangUp(_getCallByUuid(event.callUUID));
    // i dont think this should need to be ran from callkeep, since
    // it should place the call on hold if needed.
  }

  _callKeepPushkitToken(CallKeepPushKitToken event) {
    _fusionConnection.setPushkitToken(event.token);
  }

  _getCallByUuid(String uuid) {
    print("getting call by uuid");
    for (String id in callData.keys) {
      print("id");
      print(id);
      print(callData[id].toString());
      if (callData[id]['uuid'] == uuid) {
        print("found");
        return _getCallById(id);
      }
    }
    return null;
  }

  _handleStreams(CallState event, Call call) async {
    MediaStream stream = event.stream;
    if (event.originator == 'local') {
      List<MediaStream> localCallStreams = _getCallDataValue(
              call.id, "localStreams",
              def: [].cast<MediaStream>())
          .cast<MediaStream>();
      localCallStreams.add(stream);
      _setCallDataValue(call.id, "localStreams", localCallStreams);
      print("setlocalstream");
      _localStream = stream;
    }
    if (event.originator == 'remote') {
      List<MediaStream> remoteCallStreams = _getCallDataValue(
              call.id, "remoteStreams",
              def: [].cast<MediaStream>())
          .cast<MediaStream>();
      remoteCallStreams.add(stream);
      _setCallDataValue(call.id, "remoteStreams", remoteCallStreams);
      _remoteStream = stream;
    }
  }

  _didDisplayCall() {}

  _removeCall(Call call) {
    if (Platform.isIOS) {
      _getMethodChannel().invokeMethod("lpEndCall", [_uuidFor(call)]);
      _getMethodChannel().invokeMethod("endCall", [_uuidFor(call)]);
    } else if (Platform.isAndroid) {
      _getMethodChannel().invokeMethod("lpEndCall", [_uuidFor(call)]);
      _callKeep.endCall(_uuidFor(call));
    }

    if (call == activeCall) {
      activeCall = null;
      if (Platform.isAndroid) {
        incallManager.stop();
      }
      print("audioincallmanagerstop:");
    }

    List<Call> toRemove = [];

    for (Call c in calls) {
      if (c == call || c.id == call.id) {
        toRemove.add(c);
      }
    }

    for (Call c in toRemove) calls.remove(c);

    if (calls.length > 0) {
      var newActive = calls[0];
      var state = newActive.state;
      makeActiveCall(newActive);
      print("willunholdcall");
      newActive.unhold();
      _getMethodChannel().invokeMethod("lpSetHold", [_uuidFor(call), false]);
      print("setholdinvoke");
      _getMethodChannel().invokeMethod("setUnhold", [_uuidFor(call)]);
      _setLpCallState(call, CallStateEnum.CONFIRMED);
      _setCallDataValue(call.id, "onHold", false);
    } else {
      setCallOutput(call, "phone");
    }

    _updateListeners();
    if (Platform.isAndroid) {
      flutterLocalNotificationsPlugin.cancel(intIdForString(call.id));
      flutterLocalNotificationsPlugin
          .cancel(intIdForString(_getCallDataValue(call.id, "apiTermId")));
      flutterLocalNotificationsPlugin.cancel(intIdForString(call.id));
      flutterLocalNotificationsPlugin.cancelAll();
    }
  }

  _linkLnCall(toAddress, callId) {
    var call = LnCall.makeLnCall(callId, toAddress);
    _linkUuidFor(call);
    return call;
  }

  _linkLnCallWithUuid(toAddress, callId, uuid, callerId, direction) {
    print("cid");
    print(callId.toString());
    print(toAddress);
    var call = LnCall.makeLnCall(callId.toString(), toAddress);
    print(call);
    print(direction);
    call.setIdentities(toAddress, callerId, direction);
    call.setChannel(_getMethodChannel(), uuid);
    print("getdatabyid");
    print(call.id);
    Map<String, dynamic> data = _getCallDataById(call.id);
    data['uuid'] = uuid;
    print("linking call");
    print(callId);
    print(uuid);
    print(data.toString());
    return call;
  }

  testEcho() {
    _getMethodChannel().invokeMethod("lpTestEcho", []);
    isTestingEcho = true;
  }

  stopTestingEcho() {
    _getMethodChannel().invokeMethod("lpStopTestEcho", []);
    isTestingEcho = false;
  }

  calibrateEcho() {
    _getMethodChannel().invokeMethod("lpCalibrateEcho", []);
  }

  toggleEchoLimiterEnabled() {
    _getMethodChannel()
        .invokeMethod("lpSetEchoLimiterEnabled", [!echoLimiterEnabled]);
  }

  toggleEchoCancellationEnabled() {
    _getMethodChannel().invokeMethod(
        "lpSetEchoCancellationEnabled", [!echoCancellationEnabled]);
  }

  _linkUuidFor(Call call) {
    _uuidFor(call);
  }

  _uuidFor(Call call) {
    Map<String, dynamic> data = _getCallDataById(call.id);
    if (data.containsKey('uuid')) {
      return data['uuid'];
    } else {
      String uuid = uuidFromString(call.id);

      if (_awaitingCall != "none") {
        uuid = _awaitingCall;
        _awaitingCall = "none";
      } else {
        _tempUUIDs[uuid] = DateTime.now().millisecondsSinceEpoch;
      }
      data['uuid'] = uuid;
      return uuid;
    }
  }

  _removeDataFor(Call call) {
    callData.remove(call.id);
  }

  void _setCallDataValue(String id, String name, dynamic value) {
    var data = _getCallDataById(id);
    data[name] = value;
    _updateListeners();
  }

  dynamic _getCallDataValue(String id, String name, {dynamic def}) {
    var data = _getCallDataById(id);
    return data[name] == null ? def : data[name];
  }

  _getCallDataById(String id) {
    if (callData.containsKey(id)) {
      return callData[id];
    } else {
      callData[id] = Map<String, dynamic>();
      callData[id]['onHold'] = false;
      return callData[id];
    }
  }

  _getCallById(String id) {
    print("finding call" + id);
    for (Call call in calls) {
      print(call);
      print(call.id);
      if (call.id == id) {
        return call;
      }
    }
    return null;
  }

  _callIsAdded(Call call) {
    for (Call c in calls) {
      if (c.id == call.id) {
        return true;
      }
    }
    return false;
  }

  checkMicrophoneAccess(BuildContext context) async {
    print("checkmicrophone");
    PermissionStatus status = await Permission.microphone.status;
    print(status);
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.permanentlyDenied) {
      print("reqmic");
      status = await Permission.microphone.request();
    } else if (status == PermissionStatus.permanentlyDenied) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text("Mic access denied"),
                  content: Text(
                      "You must give Fusion Mobile microphone access to make calls"),
                  actions: <Widget>[
                    TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                        },
                        child: Text("OK"))
                  ]));
    }
  }

  _addCall(Call call) async {
    if (!_callIsAdded(call)) {
      if (Platform.isAndroid) {}
      calls.add(call);
      _linkUuidFor(call);

      if (activeCall == null) makeActiveCall(call);

      if (call.direction == "INCOMING") {
        _playAudio(_inboundAudioPath, false);
      } else {
        _playAudio(_outboundAudioPath, false);
      }

      if (Platform.isAndroid) {
        final bool hasPhoneAccount = await _callKeep.hasPhoneAccount();

        if (!hasPhoneAccount) {
          await _callKeep.hasDefaultPhoneAccount(_context, <String, dynamic>{
            'alertTitle': 'Permissions required',
            'alertDescription':
                'This application needs to access your phone accounts',
            'cancelButton': 'Cancel',
            'okButton': 'ok',
            'foregroundService': {
              'channelId': 'net.fusioncomm.android',
              'channelName': 'Foreground service for my app',
              'notificationTitle': 'My app is running on background',
              'notificationIcon':
                  'Path to the resource icon of the notification',
            },
          });
        }
      }

      _fusionConnection.callpopInfos.lookupPhone(call.remote_identity,
          (CallpopInfo data) {
        if (Platform.isAndroid) {
          _callKeep.updateDisplay(_uuidFor(call),
              displayName: data.getName(defaul: call.remote_display_name),
              handle: call.remote_identity);
        }
        if (call.direction == "outbound" || call.direction == "OUTGOING")
          _setCallDataValue(call.id, "callPopInfo", data);
      });

      _setCallDataValue(call.id, "startTime", DateTime.now());
    }

    if (callIdsAnswered.contains(_uuidFor(call))) answerCall(call);
  }

  onUpdate(Function listener) {
    _listeners.add(listener);
  }

  _updateListeners() {
    if (_ringingInbound &&
        (activeCall == null ||
            (activeCall.state != CallStateEnum.CONNECTING &&
                activeCall.state != null &&
                activeCall.state != CallStateEnum.PROGRESS))) {
      if (activeCall != null) {
        print("stoppingringtone");
        print(activeCall.state);
      }
      stopInbound();
    }
    if (activeCall != null && activeCall.id == "") {
      print("!!!!!!!activecall has no id???????");
    }
    for (Function listener in this._listeners) {
      listener();
    }
  }

  CallpopInfo getCallpopInfo(String id) {
    return _getCallDataValue(id, "callPopInfo") as CallpopInfo;
  }

  getCallerName(Call call) {
    if (call != null) {
      CallpopInfo data = getCallpopInfo(call.id);
      if (data != null) {
        if (data.getName().trim().length > 0)
          return data.getName();
        else
          return "Unknown";
      } else {
        if (call.remote_display_name != null &&
            call.remote_display_name.trim().length > 0)
          return call.remote_display_name;
        else
          return "Unknown";
      }
    }
  }

  String getCallerCompany(Call call) {
    if (call == null) {
      return "";
    } else {
      CallpopInfo data = getCallpopInfo(call.id);
      if (data != null) {
        return data.getCompany();
      } else {
        return "";
      }
    }
  }

  getCallerNumber(Call call) {
    return call.remote_identity;
  }

  int getCallRunTime(Call call) {
    print('call id here');
    print(call.id);
    print(_uuidFor(call));

    DateTime time = _getCallDataValue(call.id, "answerTime") as DateTime;
    if (time == null)
      time = _getCallDataValue(call.id, "startTime") as DateTime;
    if (time == null)
      return 0;
    else
      return DateTime.now().difference(time).inSeconds;
  }

  String getCallRunTimeString(Call call) {
    var duration = getCallRunTime(call);
    String callRunTime = "";
    if (duration < 60) {
      callRunTime =
          "00:" + (duration % 60 < 10 ? "0" : "") + duration.toString();
    } else if (duration < 60 * 60) {
      callRunTime = ((duration / 60).floor() < 10 ? "0" : "") +
          (duration / 60).floor().toString() +
          ":" +
          (duration % 60 < 10 ? "0" : "") +
          (duration % 60).toString();
    } else {
      int hours = (duration / (60 * 60)).floor();
      duration = duration - hours;
      callRunTime = (hours < 10 ? "0" : "") +
          hours.toString() +
          ":" +
          ((duration / 60).floor() < 10 ? "0" : "") +
          (duration / 60).floor().toString() +
          ":" +
          (duration % 60 < 10 ? "0" : "") +
          (duration % 60).toString();
    }
    return callRunTime;
  }

  getRecordState(Call call) {
    return _getCallDataValue(call.id, "isRecording", def: false);
  }

  getHoldState(Call call) {
    return call.state == CallStateEnum.HOLD;
    return _getCallDataValue(call.id, "onHold", def: false);
  }

  getCallOutput(Call call) {
    print('calloutput here' + this.outputDevice);
    return this.outputDevice == 'Speaker'
        ? 'speaker'
        : this.outputDevice == 'Bluetooth'
            ? 'bluetooth'
            : 'phone';
  }

  setCallOutput(Call call, String outputDevice) {
    print('calloutput here' + outputDevice);
    if (outputDevice == 'bluetooth') {
      setBluetooth(outputDevice == 'bluetooth');
    } else if (outputDevice == 'phone') {
      setEarpiece(outputDevice == 'phone');
    } else {
      setSpeaker(outputDevice == 'speaker');
    }
  }

  isCallMerged(Call call) {
    return _getCallDataValue(call.id, "mergedWith") != null;
  }

  mergedCall(Call call) {
    return _getCallById(_getCallDataValue(call.id, "mergedWith"));
  }

  mergeCalls(Call call, Call call2) {
    if (_isUsingUa) {
      call2.peerConnection.getLocalDescription().then((value) {});
      call.peerConnection.getLocalDescription().then((value) {});
      MediaStream call2Remote = call2.peerConnection.getRemoteStreams()[1];
      call.peerConnection.getRemoteStreams().map((MediaStream m) {
        call2.peerConnection.addStream(m);
        m.getAudioTracks().map((MediaStreamTrack mt) {
          call2.peerConnection.addTrack(mt);
        });
      });
      MediaStream callRemote = call.peerConnection.getRemoteStreams()[1];
      call2.peerConnection.getRemoteStreams().map((MediaStream m) {
        call.peerConnection.addStream(m);
        m.getAudioTracks().map((MediaStreamTrack mt) {
          call.peerConnection.addTrack(mt);
        });
      });
      _setCallDataValue(call.id, "mergedWith", call2.id);
      _setCallDataValue(call2.id, "mergedWith", call.id);

      createLocalMediaStream('local').then((MediaStream mergedStream) {
        call.peerConnection.getLocalStreams().map((MediaStream m) {
          m.getAudioTracks().map((MediaStreamTrack mt) {
            mergedStream.addTrack(mt);
          });
        });

        call2.peerConnection.getRemoteStreams().map((MediaStream m) {
          m.getAudioTracks().map((MediaStreamTrack mt) {
            mergedStream.addTrack(mt);
          });
        });

        call.peerConnection
            .getLocalStreams()
            .map((stream) => call.peerConnection.removeStream(stream));
        call.peerConnection.addStream(mergedStream);
      });
    }
  }

  recordCall(Call call) {
    _setCallDataValue(call.id, "isRecording", true);
    Map<String, String> ids = _getCallApiIds(call);

    _fusionConnection.nsApiCall("call", "record_on",
        {"callid": ids['orig'], "uid": _fusionConnection.getUid()},
        callback: (Map<String, dynamic> result) {});
  }

  stopRecordCall(Call call) {
    _setCallDataValue(call.id, "isRecording", false);
    Map<String, String> ids = _getCallApiIds(call);
    _fusionConnection.nsApiCall("call", "record_off",
        {"callid": ids['orig'], "uid": _fusionConnection.getUid()},
        callback: (Map<String, dynamic> result) {});
  }

  blockAndroidAudioEvents(int time) {
    _blockingEvent = true;
    var future = new Future.delayed(Duration(milliseconds: time), () {
      _blockingEvent = false;
    });
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    print("callstatechange " + callState.state.name);
    try {
      switch (callState.state) {
        case CallStateEnum.STREAM:
          _blockingEvent = true;
          var future =
              new Future.delayed(const Duration(milliseconds: 2000), () {
            _blockingEvent = false;
          });
          _handleStreams(callState, call);
          if (Platform.isIOS) {
            if (!isIncoming(call)) {
              _callKit.invokeMethod(
                  "reportConnectedOutgoingCall", [_uuidFor(call)]);
            }
            // for some reason ios defaults to speakerphone and wont let me change
            // that until after this event.
            for (var i = 1250; i < 10000; i += 1500) {
              var future = new Future.delayed(Duration(milliseconds: i), () {
                setCallOutput(call, getCallOutput(call));
              });
            }
          }
          break;
        case CallStateEnum.ENDED:
          stopOutbound();
          stopInbound();
          _removeCall(call);
          break;
        case CallStateEnum.FAILED:
          if (Platform.isAndroid) {
            toast(
                "call failed, " +
                    callState.refer.toString() +
                    callState.toString() +
                    callState.cause.toString() +
                    " - " +
                    callState.originator.toString(),
                duration: Toast.LENGTH_LONG);

            /* Sentry.captureMessage(
                "callkit failed:" +
                    callState.refer.toString() +
                    callState.toString() +
                    callState.cause.toString() +
                    " - " +
                    callState.originator.toString(),
                hint: callState);*/
          }
          stopOutbound();
          stopInbound();
          _removeCall(call);
          break;
        case CallStateEnum.UNMUTED:
          _setCallDataValue(call.id, "muted", false);
          break;
        case CallStateEnum.MUTED:
          _setCallDataValue(call.id, "muted", true);
          break;
        case CallStateEnum.CONNECTING:
          break;
        case CallStateEnum.PROGRESS:
          break;
        case CallStateEnum.ACCEPTED:
          _blockingEvent = true;
          var future =
              new Future.delayed(const Duration(milliseconds: 2000), () {
            _blockingEvent = false;
          });
          if (Platform.isAndroid) {
            setCallOutput(call, getCallOutput(call));
          }
          break;
        case CallStateEnum.CONFIRMED:
          print("confirmed now");
          stopOutbound();
          stopInbound();
          // if (Platform.isAndroid) {
          //   setCallOutput(call, getCallOutput(call));
          // }
          _setCallDataValue(call.id, "answerTime", DateTime.now());

          _blockingEvent = true;
          var future =
              new Future.delayed(const Duration(milliseconds: 2000), () {
            _blockingEvent = false;
          });

          if (!isIncoming(call)) {
            if (Platform.isAndroid) {
              _callKeep.reportConnectedOutgoingCallWithUUID(_uuidFor(call));
            }
          } else {
            if (Platform.isAndroid) {
              _callKeep.answerIncomingCall(_uuidFor(call));
            }
          }
          break;
        case CallStateEnum.HOLD:
          _setCallDataValue(call.id, "onHold", true);
          break;
        case CallStateEnum.UNHOLD:
          _setCallDataValue(call.id, "onHold", false);
          break;
        case CallStateEnum.NONE:
          break;
        case CallStateEnum.CALL_INITIATION:
          _addCall(call);
          if (Platform.isAndroid) {
            setCallOutput(call, getCallOutput(call));

            if (isIncoming(call)) {
              _callKeep.displayIncomingCall(
                  _uuidFor(call), getCallerName(call));
            } else {
              _callKeep.startCall(
                  _uuidFor(call), getCallerNumber(call), getCallerName(call));
            }
            if (Platform.isAndroid) {
              _blockingEvent = true;
              var future =
                  new Future.delayed(const Duration(milliseconds: 2000), () {
                _blockingEvent = false;
              });

              //TODO: do this in a less hacky way
              for (var i = 1000; i < 10000; i += 1500) {
                var future = new Future.delayed(Duration(milliseconds: i), () {
                  _callKeep.updateDisplay(_uuidFor(call),
                      handle: getCallerNumber(call),
                      displayName: getCallerName(call));
                });
              }
            }
          }
          if (!isIncoming(call) && Platform.isIOS) {
            _callKit
                .invokeMethod("reportConnectingOutgoingCall", [_uuidFor(call)]);
          }
          break;
        case CallStateEnum.REFER:
          break;
      }
    } catch (e) {
      print("call event error");
      print(e);
    }
    try {
      _updateListeners();
    } catch (e) {
      print("listener update error");
      print(e);
    }
    _checkAudio();
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void registrationStateChanged(RegistrationState state) {
    if (state.state == RegistrationStateEnum.UNREGISTERED) {
      registered = false;
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      if (_onUnregister != null) {
        _onUnregister();
        _onUnregister = null;
      }
      registered = false;
    } else if (state.state == RegistrationStateEnum.NONE) {
      registered = this.helper.registered;
    } else if (state.state == RegistrationStateEnum.REGISTERED) {
      registered = true;
    }
    connected = this.helper.connected;
    _updateListeners();

    if (!registered) {
      var future = new Future.delayed(const Duration(milliseconds: 10000), () {
        if (!this.helper.registered) this.reregister();
      });
    }
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewNotify(ntf) {
    print("new notify");
    print(ntf);
  }

  void stopRinging(String uuid) {
    try {
      _callKit.invokeMethod('stopRinging', [uuid]);
      hangUp(_getCallByUuid(uuid));
    } on PlatformException catch (e) {
      print("callkit outgoing error");
    }
  }

  void onUnregister(Function() fn) {
    _onUnregister = fn;
  }

  void forceupdateOutputDevice(String deviceId) {
    _savedOutput = true;
    setDefaultOutput(deviceId);
  }

  void switchToHeadsetWhenConnected() {
    devicesList.forEach((element) {
      final validBluetoothDevice =
          RegExp(r'(openSLES Bluetooth:).*').hasMatch(element[1]);
      final validBluetoothInputDevice =
          RegExp(r'(openSLES Microphone:).*').hasMatch(element[1]);
      if (validBluetoothDevice &&
          defaultOutput != element[1] &&
          !_savedOutput) {
        _savedOutput = true;
        setDefaultOutput(element[1]);
        this.outputDevice = 'Bluetooth';
      }
      // openSLES Microphone should always be the default mic, if the bt device
      // have a mic it will be capturing the voice from the bt device, otherwise
      // it will capture voice from phone mic
      if (validBluetoothInputDevice &&
          defaultInput != element[1] &&
          !_savedOutput) {
        setDefaultInput(element[1]);
      }
      _updateListeners();
    });
  }
}
