import 'dart:async';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/callpop/call_action_buttons.dart';
import 'package:fusion_mobile_revamped/src/callpop/call_dialpad.dart';
import 'package:fusion_mobile_revamped/src/callpop/call_footer_details.dart';
import 'package:fusion_mobile_revamped/src/callpop/call_header_details.dart';
import 'package:fusion_mobile_revamped/src/callpop/incoming_while_on_call.dart';
import 'package:fusion_mobile_revamped/src/callpop/transfer_call_popup.dart';
import 'package:fusion_mobile_revamped/src/callpop/viewModel.dart';
import 'package:fusion_mobile_revamped/src/chats/conversationView.dart';
import 'package:fusion_mobile_revamped/src/components/disposition.dart';
import 'package:fusion_mobile_revamped/src/components/popup_menu.dart';
import 'package:fusion_mobile_revamped/src/dialpad/dialpad_modal.dart';
import 'package:fusion_mobile_revamped/src/messages/sms_conversation_view.dart';
import 'package:fusion_mobile_revamped/src/models/callpop_info.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:sip_ua/sip_ua.dart';
import '../models/conversations.dart';
import '../models/coworkers.dart';
import '../utils.dart';

import 'answered_while_on_call.dart';

class CallView extends StatefulWidget {
  CallView(this._fusionConnection, this._softphone, {Key? key, this.closeView})
      : super(key: key);

  final VoidCallback? closeView;
  final FusionConnection _fusionConnection;
  final Softphone _softphone;

  @override
  State<StatefulWidget> createState() => _CallViewState();
}

class _CallViewState extends State<CallView> {
  Softphone get _softphone => widget._softphone;
  FusionConnection get _fusionConnection => widget._fusionConnection;
  Call? get _activeCall => _softphone.activeCall;
  List<Call> get _allCalls => _softphone!.calls;

  bool dialpadVisible = false;
  late Timer _timer;
  bool TextBtnPressed = false;
  bool _showDisposition = false;
  final CallVM callVM = CallVM();
  String _myPhoneNumber = "";
  bool openCallQualityPill = false;
  bool userOverride = false;

  initState() {
    super.initState();
    _myPhoneNumber = _fusionConnection.settings.myCellPhoneNumber;
    _timer = new Timer.periodic(
      Duration(seconds: 1),
      (Timer timer) {
        setState(() {});
      },
    );
    _softphone!.checkMicrophoneAccess(context);
  }

  @override
  dispose() {
    _timer.cancel();
    callVM.dispose();
    super.dispose();
  }

  _onHoldBtnPress() {
    _softphone!.setHold(_activeCall!, true, true);
  }

  _onResumeBtnPress() {
    if (Platform.isIOS &&
        _softphone!.couldGetAudioSession == _softphone!.activeCall!.id) {
      String? num = _softphone!.getCallerNumber(_softphone!.activeCall!);
      _softphone!.hangUp(_softphone!.activeCall!);
      _softphone!.makeCall(num);
    } else if (!_softphone!.isCellPhoneCallActive!)
      _softphone!.setHold(_activeCall!, false, true);
  }

  _makeXferUrl(String url) {
    if (url.contains("@"))
      return 'sip:' + url;
    else
      return url;
  }

  _onXferBtnPress() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (contact) =>
            TransferCallPopup(_fusionConnection, _softphone, () {
              Navigator.pop(context);
            }, (String xferTo, String xferType) {
              if (xferType == "blind") {
                _softphone.transfer(_activeCall!, _makeXferUrl(xferTo));
              } else if (xferType == "assisted") {
                _softphone.assistedTransfer(_activeCall, _makeXferUrl(xferTo));
              }
              Navigator.pop(context);
            }));
  }

  _onDialBtnPress() {
    if (_softphone!.getHoldState(_activeCall)) {
      setState(() {
        dialpadVisible = false;
        showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => DialPadModal(_fusionConnection, _softphone));
      });
    } else {
      setState(() {
        dialpadVisible = !dialpadVisible;
      });
    }
  }

  _onParkBtnPress() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) =>
            DialPadModal(_fusionConnection, _softphone, initialTab: 0));
  }

  _onMergeBtnPress() {
    if (_softphone.mergingCalls) return;
    if (_softphone.calls.length == 1) {
      setState(() {
        dialpadVisible = false;
        showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => DialPadModal(_fusionConnection, _softphone));
      });
    } else {
      _softphone.mergeCalls();
    }
  }

  _onRecBtnPress() {
    if (_softphone!.getRecordState(_activeCall!)) {
      _softphone!.stopRecordCall(_activeCall!);
    } else {
      _softphone!.recordCall(_activeCall!);
    }
  }

  _onVidBtnPress() {}

  _onTextBtnPress() async {
    if (TextBtnPressed) return;

    setState(() {
      TextBtnPressed = true;
    });

    List<Coworker> coworkers = _fusionConnection!.coworkers.getRecords();
    String ext = _activeCall!.remote_identity!.onlyNumbers();
    List<Coworker> coworker =
        coworkers.where((coworker) => coworker.extension == ext).toList();
    CallpopInfo? callPopInfo = _softphone!.getCallpopInfo(_activeCall!.id);
    SMSDepartment personal =
        _fusionConnection!.smsDepartments.getDepartment(DepartmentIds.Personal);
    List<SMSDepartment> depts =
        _fusionConnection!.smsDepartments.allDepartments();

    if (personal.numbers.isEmpty && depts.isEmpty ||
        (depts[1].numbers.isEmpty || coworker.isNotEmpty)) {
      setState(() {
        TextBtnPressed = false;
      });
      return showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
                title: const Text('Woops!'),
                content: Text(coworker.isNotEmpty
                    ? "Internal messaging not supported"
                    : "Looks like you don't have messaging numbers setup yet."),
                actions: <Widget>[
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        "Okay",
                        style: TextStyle(color: crimsonDark),
                      ))
                ]);
          });
    }

    SMSConversation? convo = await _fusionConnection!.messages
        .checkExistingConversation(
            personal.numbers.isNotEmpty ? personal.id! : depts[1].id!,
            personal.numbers.isNotEmpty
                ? personal.numbers[0]
                : depts[1].numbers[0],
            callPopInfo != null && callPopInfo.phoneNumber.isNotEmpty
                ? [callPopInfo.phoneNumber]
                : [_softphone!.getCallerNumber(_softphone!.activeCall!)],
            callPopInfo != null ? callPopInfo.contacts : []);

    setState(() {
      TextBtnPressed = false;
    });

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => ConversationView(
            conversation: convo,
            isNewConversation: convo.conversationId == null));
  }

  _changeDefaultInputDevice() {
    List<List<String>> options = _softphone!.devicesList
        .where((element) => element[2] == "Microphone")
        .toList()
        .cast<List<String>>();
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (contact) => PopupMenu(
            label: "Default Input Device",
            bottomChild: Container(
                constraints: BoxConstraints(
                    minHeight: 24,
                    maxHeight: 200,
                    minWidth: 90,
                    maxWidth: MediaQuery.of(context).size.width - 66),
                child: ListView(
                    padding: EdgeInsets.all(8),
                    children: options.map((List<String> option) {
                      return GestureDetector(
                          onTap: () {
                            _softphone!.setDefaultInput(option[1]);
                            Navigator.pop(context);
                          },
                          child: Container(
                              padding: EdgeInsets.only(
                                  top: 12, bottom: 12, left: 8, right: 8),
                              decoration: BoxDecoration(
                                  color: option[1] == _softphone!.defaultInput
                                      ? lightHighlight
                                      : Colors.transparent,
                                  border: Border(
                                      bottom: BorderSide(
                                          color: lightDivider, width: 1.0))),
                              child: Row(children: [
                                Text(option[0],
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                Spacer(),
                                if (_softphone!.defaultInput == option[1])
                                  Image.asset(
                                      "assets/icons/call_view/check.png",
                                      width: 16,
                                      height: 11)
                              ])));
                    }).toList()))));
  }

  _changeDefaultOutputDevice() {
    List<List<String?>> options = Platform.isAndroid
        ? _softphone!.devicesList
            .where((element) => element[2] != "Microphone")
            .toList()
            .cast<List<String>>()
        : _softphone!.devicesList;
    String? callDefaultOutputDeviceId = _softphone!.activeCallOutputDevice != ''
        ? _softphone!.activeCallOutputDevice
        : _softphone!.defaultOutput;
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (contact) => PopupMenu(
            label: "Default Output Device",
            bottomChild: Container(
                constraints: BoxConstraints(
                    minHeight: 24,
                    maxHeight: 200,
                    minWidth: 90,
                    maxWidth: MediaQuery.of(context).size.width - 66),
                child: ListView(
                    padding: EdgeInsets.all(8),
                    children: options.map((List<String?> option) {
                      return GestureDetector(
                          onTap: () {
                            _softphone!.setActiveCallOutputDevice(option[1]);
                            Navigator.pop(context);
                          },
                          child: Container(
                              padding: EdgeInsets.only(
                                  top: 12, bottom: 12, left: 8, right: 8),
                              decoration: BoxDecoration(
                                  color: option[1] == callDefaultOutputDeviceId
                                      ? lightHighlight
                                      : Colors.transparent,
                                  border: Border(
                                      bottom: BorderSide(
                                          color: lightDivider, width: 1.0))),
                              child: Row(children: [
                                Text(
                                    option[0]!
                                        .replaceAll('Microphone', 'Earpiece'),
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                Spacer(),
                                if (callDefaultOutputDeviceId == option[1])
                                  Image.asset(
                                      "assets/icons/call_view/check.png",
                                      width: 16,
                                      height: 11)
                              ])));
                    }).toList()))));
  }

  _onAudioBtnPress() {
    print("audiopress");
    print(_softphone!.devicesList);
    print(_softphone!.defaultInput);
    List<List<String>> options = [
      ["assets/icons/call_view/audio_phone.png", "Phone", "phone"],
      ["assets/icons/call_view/audio_speaker.png", "Speaker", "speaker"],
      ["assets/icons/call_view/bluetooth.png", "Bluetooth", "bluetooth"],
    ];
    String? callAudioOutput = _softphone!.activeCallOutput != ''
        ? _softphone!.activeCallOutput
        : _softphone!.outputDevice;
    String? callDefaultOutputDeviceId = _softphone!.activeCallOutputDevice != ''
        ? _softphone!.activeCallOutputDevice
        : _softphone!.defaultOutput;
    bool? muted = _softphone!.getMuted(_activeCall!);

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (contact) => PopupMenu(
            label: "AUDIO SOURCE",
            bottomChild: Container(
                constraints: BoxConstraints(
                    minHeight: 24,
                    maxHeight: 160,
                    minWidth: 90,
                    maxWidth: MediaQuery.of(context).size.width - 136),
                child: ListView(
                    padding: EdgeInsets.all(8),
                    children: options.map((List<String> option) {
                      return GestureDetector(
                          onTap: () {
                            if (option[1] == "Bluetooth" &&
                                !_softphone!.bluetoothAvailable) {
                              return;
                            }
                            _softphone!.setCallOutput(_activeCall, option[2]);
                            Navigator.pop(context);
                          },
                          child: Container(
                              padding: EdgeInsets.only(
                                  top: 12, bottom: 12, left: 18, right: 18),
                              decoration: BoxDecoration(
                                  color: option[1] == callAudioOutput
                                      ? lightHighlight
                                      : Colors.transparent,
                                  border: Border(
                                      bottom: BorderSide(
                                          color: lightDivider, width: 1.0))),
                              child: Row(children: [
                                Image.asset(option[0], width: 15, height: 15),
                                Container(width: 12),
                                Text(option[1],
                                    style: TextStyle(
                                        color: option[1] == "Bluetooth" &&
                                                !_softphone!.bluetoothAvailable
                                            ? Colors.white60
                                            : Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                                Spacer(),
                                if (callAudioOutput == option[1])
                                  Image.asset(
                                      "assets/icons/call_view/check.png",
                                      width: 16,
                                      height: 11)
                              ])));
                    }).toList()))));
  }

  _onMuteBtnPress() {
    _softphone!.setMute(_activeCall, !_softphone!.getMuted(_activeCall!), true);
  }

  _onHangup() {
    _softphone.hangUp(_activeCall!);
    widget.closeView!();
  }

  _onAnswer() {
    _softphone!.answerCall(_activeCall);
  }

  _onHoldView() {
    return Expanded(
        child: Container(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('ON HOLD',
              style: TextStyle(
                  color: translucentWhite(0.67),
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w700)),
          GestureDetector(
              onTap: _onResumeBtnPress,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    alignment: Alignment.center,
                    padding: EdgeInsets.only(
                        top: 12, left: 16, right: 16, bottom: 12),
                    margin: EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
                        color: translucentWhite(0.2)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!_softphone!.isCellPhoneCallActive! &&
                            !(_softphone!.couldGetAudioSession !=
                                    _softphone!.activeCall &&
                                Platform.isIOS))
                          Container(
                              margin: EdgeInsets.only(right: 8),
                              child: Image.asset(
                                  "assets/icons/call_view/play.png",
                                  width: 12,
                                  height: 16)),
                        Text(
                            _softphone!.isCellPhoneCallActive!
                                ? 'Mobile Call Active'
                                : (_softphone!.couldGetAudioSession ==
                                            _softphone!.activeCall!.id &&
                                        Platform.isIOS
                                    ? 'RESUME'
                                    : 'RESUME'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                height: 1.2))
                      ],
                    ),
                  )
                ],
              )),
        ],
      ),
    ));
  }

  void _openDisposition() {
    setState(() {
      _showDisposition = !_showDisposition;
    });
  }

  Color _callQualityColor(double rating) {
    return rating > 4
        ? successGreen
        : rating > 3 || (rating < 3 && callVM.lowScore < 2)
            ? Colors.amber
            : Colors.red;
  }

  String _callQualityTitle(double rating) {
    return rating > 4
        ? "Good"
        : rating > 3 || (rating < 3 && callVM.lowScore < 2)
            ? "Average"
            : "Poor";
  }

  double _getPillWidth(double rating) {
    Size text = textSize(
        _callQualityTitle(rating) +
            ": call quality ${rating.toStringAsFixed(1)}/5.0",
        TextStyle(fontSize: 20));
    return !openCallQualityPill
        ? text.width
        : MediaQuery.of(context).size.width - 10;
  }

  Widget _callPillClosed(double rating) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 10,
          width: 10,
          child: DecoratedBox(
              decoration: BoxDecoration(
                  color: _callQualityColor(rating), shape: BoxShape.circle)),
        ),
        SizedBox(
          width: 5,
        ),
        Text(
          _callQualityTitle(rating),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _callPillOpen(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
            height: 10,
            width: 10,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: _callQualityColor(rating), shape: BoxShape.circle))),
        SizedBox(width: 5),
        Text(
          _callQualityTitle(rating) +
              ": call quality ${rating.toStringAsFixed(1)}/5.0",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        Spacer(),
        TextButton(
          onPressed: _dialog,
          child: Text("XFER TO CARRIER"),
          style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              foregroundColor: Colors.white,
              backgroundColor: char,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6))),
        ),
      ],
    );
  }

  Future<void> _dialog() async {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 24),
              title: Text("Transfer to Carrier"),
              content: Container(
                child: Wrap(
                  runSpacing: 16,
                  children: [
                    Text("This active call is about to be transferred to"),
                    TextFormField(
                      keyboardType: TextInputType.phone,
                      maxLength: 14,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        InputPhoneFormatter()
                      ],
                      decoration: InputDecoration(
                        labelText: "Phone number",
                        counterText: "",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      initialValue: _myPhoneNumber.formatPhone(),
                      onChanged: (value) {
                        setDialogState(
                          () {
                            setState(() {
                              _myPhoneNumber = value.onlyNumbers();
                            });
                          },
                        );
                      },
                    )
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: crimsonLight),
                  onPressed: _myPhoneNumber.length < 10
                      ? null
                      : () {
                          _softphone.transfer(
                              _activeCall!, _makeXferUrl(_myPhoneNumber));
                          Navigator.of(context).pop();
                        },
                  child: Text("Transfer"),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.all(0), foregroundColor: coal),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel"),
                ),
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_activeCall == null) {
      return Container();
    }
    var companyName =
        _softphone.confCreated ? "" : _softphone.getCallerCompany(_activeCall);
    var callerName = _softphone.confCreated
        ? "Conference"
        : _softphone.getCallerName(_activeCall);
    String _linePrefix = _softphone.confCreated ? "" : _softphone.linePrefix;
    var callerNumber =
        _softphone!.getCallerNumber(_activeCall!); // 'mobile' | 'work' ...etc

    Map<String, Function()> actions = {
      'onHoldBtnPress': _onHoldBtnPress,
      'onResumeBtnPress': _onResumeBtnPress,
      'onXferBtnPress': _onXferBtnPress,
      'onDialBtnPress': _onDialBtnPress,
      'onParkBtnPress': _onParkBtnPress,
      'onConfBtnPress': _onMergeBtnPress,
      'onRecBtnPress': _onRecBtnPress,
      'onVidBtnPress': _onVidBtnPress,
      'onMuteBtnPress': _onMuteBtnPress,
      'onTextBtnPress': _onTextBtnPress,
      'onAudioBtnPress': _onAudioBtnPress,
      'onHangup': _onHangup,
      'onAnswer': _onAnswer,
    };

    String callRunTime = _softphone!.getCallRunTimeString(_activeCall!);

    bool isIncoming = _softphone!.isIncoming(_activeCall!);
    bool isRinging = !_softphone!.isConnected(_activeCall!);

    Call? incomingCall = null;
    List<Call> connectedCalls = [];

    for (Call c in _allCalls) {
      if (c != _activeCall && !_softphone!.isConnected(c))
        incomingCall = c;
      else if (c != _activeCall) connectedCalls.add(c);
    }

    return WillPopScope(
        onWillPop: () async {
          return false;
        },
        child: GestureDetector(
          onTap: () {
            FocusScopeNode currentFocus = FocusScope.of(context);
            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.unfocus();
            }
          },
          child: Container(
              decoration: BoxDecoration(
                  image: DecorationImage(
                      colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.8), BlendMode.dstATop),
                      image: _softphone!.getCallerPic(_activeCall),
                      fit: BoxFit.cover)),
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: _showDisposition ? 21 : 0,
                      sigmaY: _showDisposition ? 21 : 0),
                  child: Stack(
                    children: [
                      if (_softphone!.getHoldState(_activeCall) ||
                          dialpadVisible)
                        Container(
                            child: Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [translucentWhite(0.0), Colors.black],
                          )),
                        )),
                      if (_softphone!.getHoldState(_activeCall) ||
                          dialpadVisible)
                        ClipRect(
                            child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 21, sigmaY: 21),
                                child: Container())),
                      SafeArea(
                          bottom: false,
                          child: Container(
                            child: Column(
                              children: [
                                // if (Platform.isIOS && isIncoming && isRinging)
                                //   CallActionButtons(
                                //       actions: actions,
                                //       isRinging: isRinging,
                                //       isIncoming: isIncoming,
                                //       dialPadOpen: dialpadVisible,
                                //       resumeDisabled:
                                //           _softphone.isCellPhoneCallActive,
                                //       isOnConference:
                                //           _softphone.isCallMerged(_activeCall),
                                //       setDialpad: (bool isOpen) {
                                //         setState(() {
                                //           dialpadVisible = isOpen;
                                //         });
                                //       },
                                //       callIsRecording:
                                //           _softphone.getRecordState(_activeCall),
                                //       callIsMuted: _softphone.getMuted(_activeCall),
                                //       callOnHold:
                                //           _softphone.getHoldState(_activeCall)),
                                CallHeaderDetails(
                                    callerName: callerName,
                                    companyName: companyName,
                                    callerNumber:
                                        callerNumber.toString().formatPhone(),
                                    isRinging: isRinging,
                                    prefix: _activeCall!.direction ==
                                                "INCOMING" ||
                                            _activeCall!.direction == "inbound"
                                        ? _linePrefix
                                        : "",
                                    callIsRecording: _softphone!
                                        .getRecordState(_activeCall!),
                                    callRunTime: callRunTime),
                                if (_softphone!.getHoldState(_activeCall))
                                  _onHoldView()
                                else
                                  _showDisposition
                                      ? Expanded(
                                          child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 5),
                                          child: DispositionListView(
                                              fromCallView: true,
                                              softphone: _softphone,
                                              fusionConnection:
                                                  _fusionConnection,
                                              call: _activeCall,
                                              phoneNumber: callerNumber,
                                              onDone: _openDisposition),
                                        ))
                                      : Spacer(),
                                if (!_softphone!.getHoldState(_activeCall) &&
                                    dialpadVisible)
                                  CallDialPad(_softphone, _activeCall),
                                if (_activeCall != null &&
                                    _softphone.isConnected(_activeCall!))
                                  Container(
                                    alignment: Alignment.topRight,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          openCallQualityPill =
                                              !openCallQualityPill;
                                          userOverride = !userOverride;
                                        });
                                      },
                                      child: StreamBuilder(
                                          stream: callVM.eventStream,
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData)
                                              return Container();
                                            double rating = snapshot.data;

                                            if (callVM.lowScore > 2 &&
                                                !userOverride) {
                                              openCallQualityPill = true;
                                            } else {
                                              if (openCallQualityPill &&
                                                  !userOverride) {
                                                openCallQualityPill = false;
                                              }
                                            }

                                            return AnimatedContainer(
                                              margin: EdgeInsets.only(
                                                  bottom: 10,
                                                  right: openCallQualityPill
                                                      ? 5
                                                      : 20),
                                              curve: openCallQualityPill
                                                  ? Curves.ease
                                                  : Curves.easeIn,
                                              width: openCallQualityPill
                                                  ? _getPillWidth(rating)
                                                  : 105,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        openCallQualityPill
                                                            ? 16
                                                            : 100),
                                                color: translucentBlack(1.5),
                                              ),
                                              duration: const Duration(
                                                  milliseconds: 500),
                                              child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                      vertical: 10,
                                                      horizontal: 16),
                                                  child: openCallQualityPill
                                                      ? _callPillOpen(rating)
                                                      : _callPillClosed(
                                                          rating)),
                                            );
                                          }),
                                    ),
                                  ),
                                if ((!Platform.isIOS ||
                                        !isIncoming ||
                                        !isRinging) &&
                                    !_showDisposition)
                                  CallActionButtons(
                                      actions: actions,
                                      isRinging: isRinging,
                                      isIncoming: isIncoming,
                                      dialPadOpen: dialpadVisible,
                                      isMergeDisabled:
                                          !_softphone.isConferencable(),
                                      setDialpad: (bool isOpen) {
                                        setState(() {
                                          dialpadVisible = isOpen;
                                        });
                                      },
                                      currentAudioSource:
                                          _softphone.outputDevice,
                                      loading: TextBtnPressed,
                                      callIsRecording: _softphone!
                                          .getRecordState(_activeCall!),
                                      callIsMuted:
                                          _softphone!.getMuted(_activeCall!),
                                      callOnHold: _softphone!
                                          .getHoldState(_activeCall)),
                                CallFooterDetails(
                                    _softphone, _activeCall, _openDisposition)
                              ],
                            ),
                          )),
                      if (connectedCalls.length > 0 &&
                          _activeCall != null &&
                          !_softphone.confCreated)
                        AnsweredWhileOnCall(
                            calls: connectedCalls,
                            softphone: _softphone,
                            activeCall: _activeCall!),
                      if (incomingCall != null)
                        IncomingWhileOnCall(
                            call: incomingCall, softphone: _softphone)
                    ],
                  ),
                ),
              )),
        ));
  }
}
