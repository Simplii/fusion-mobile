import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/components/popup_menu.dart';
import 'package:fusion_mobile_revamped/src/models/dids.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/models/user_settings.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../backend/fusion_connection.dart';
import '../backend/softphone.dart';
import '../models/contact.dart';
import '../styles.dart';
import '../utils.dart';

class Menu extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final Softphone _softphone;

  Menu(this._fusionConnection, this._softphone, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  FusionConnection get _fusionConnection => widget._fusionConnection;
  Softphone get _softphone => widget._softphone;
  bool loggingOut = false;

  String? selectedOutboundDid = "";
  List<Did> dynamicDailingDids = [];
  bool? usingCarrierCalls = false;
  String? myPhoneNumber = "";
  late UserSettings userSettings;
  bool? DND = false;
  bool disableSyncCallsToIPhone = UserSettings.disableSyncCallsToIPhone;
  @override
  initState() {
    super.initState();
    userSettings = _fusionConnection.settings;
    DND = userSettings!.dnd;
    myPhoneNumber = userSettings!.myCellPhoneNumber!.isNotEmpty
        ? userSettings!.myCellPhoneNumber!.formatPhone()
        : _softphone!.devicePhoneNumber;
    usingCarrierCalls = userSettings!.usesCarrier;
    _fusionConnection!.nsAnsweringRules().then((Map<String, dynamic> value) {
      userSettings!.devices = value['devices'];
      if (userSettings!.usesCarrier != value["usesCarrier"]) {
        setState(() {
          usingCarrierCalls = value["usesCarrier"];
          if (value["usesCarrier"]) {
            myPhoneNumber = value["phoneNumber"];
          }
        });
        List<SettingsPayload> payload = [
          SettingsPayload(_fusionConnection!.getUid(), "uses_carrier",
              value["usesCarrier"] ? value["usesCarrier"].toString() : "")
        ];
        if (value["usesCarrier"]) {
          payload.add(SettingsPayload(_fusionConnection!.getUid(),
              "cell_phone_number", value['phoneNumber']));
        }
        userSettings!.updateUserSettings(payload);
      }
    });
    List<SMSDepartment> deps =
        _fusionConnection!.smsDepartments.allDepartments();
    selectedOutboundDid = userSettings!.myOutboundCallerId;
    Iterable filter =
        deps.where((SMSDepartment dep) => dep.usesDynamicOutbound!);
    List<SMSDepartment> dynamicDailingDepts =
        userSettings!.dynamicDialingIsActive &&
                deps.isNotEmpty &&
                filter.isNotEmpty
            ? filter.toList() as List<SMSDepartment>
            : [];
    dynamicDailingDepts.forEach((SMSDepartment dep) {
      dynamicDailingDids.add(dep.toDid());
    });
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
                            // _softphone.setDefaultOutput(option[1]);
                            _softphone!.forceupdateOutputDevice(option[1]);
                            Navigator.pop(context);
                          },
                          child: Container(
                              padding: EdgeInsets.only(
                                  top: 12, bottom: 12, left: 8, right: 8),
                              decoration: BoxDecoration(
                                  color: option[1] == _softphone!.defaultOutput
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
                                if (_softphone!.defaultOutput == option[1])
                                  Image.asset(
                                      "assets/icons/call_view/check.png",
                                      width: 16,
                                      height: 11)
                              ])));
                    }).toList()))));
  }

  _onAudioBtnPress() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (contact) => PopupMenu(
            label: "Default Audio Sources",
            topChild: Column(children: [
              Row(children: [
                Expanded(
                    child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _changeDefaultOutputDevice();
                        },
                        child: Container(
                            alignment: Alignment.center,
                            margin: EdgeInsets.only(
                                bottom: 4, left: 20, right: 20, top: 6),
                            padding: EdgeInsets.only(top: 12, bottom: 12),
                            decoration: BoxDecoration(
                                color: coal,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                                boxShadow: [
                                  BoxShadow(
                                      color: translucentBlack(0.28),
                                      offset: Offset.zero,
                                      blurRadius: 36)
                                ]),
                            child: Text(
                                _softphone!.defaultOutput!
                                    .replaceAll('Microphone', 'Earpiece'),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  height: 1.4,
                                )))))
              ]),
              Container(height: 4),
              Row(children: [
                Expanded(
                    child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _changeDefaultInputDevice();
                        },
                        child: Container(
                            alignment: Alignment.center,
                            margin: EdgeInsets.only(
                                bottom: 16, left: 20, right: 20, top: 6),
                            padding: EdgeInsets.only(top: 12, bottom: 12),
                            decoration: BoxDecoration(
                                color: coal,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                                boxShadow: [
                                  BoxShadow(
                                      color: translucentBlack(0.28),
                                      offset: Offset.zero,
                                      blurRadius: 36)
                                ]),
                            child: Text(_softphone!.defaultInput!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  height: 1.4,
                                )))))
              ])
            ]),
            bottomChild: Container(
                constraints: BoxConstraints(
                    minHeight: 24,
                    maxHeight: 200,
                    minWidth: 90,
                    maxWidth: MediaQuery.of(context).size.width - 135),
                child: ListView(padding: EdgeInsets.all(8), children: [
                  GestureDetector(
                      onTap: () {
                        _softphone!.toggleEchoCancellationEnabled();
                        Navigator.pop(context);
                      },
                      child: Container(
                          padding: EdgeInsets.only(
                              top: 12, bottom: 12, left: 18, right: 18),
                          decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border(
                                  bottom: BorderSide(
                                      color: lightDivider, width: 1.0))),
                          child: Row(children: [
                            Text(
                                (_softphone!.echoCancellationEnabled!
                                    ? "Disable Echo Cancellation"
                                    : "Enable Echo Cancellation"),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          ]))),
                  GestureDetector(
                      onTap: () {
                        _softphone!.toggleEchoLimiterEnabled();
                        Navigator.pop(context);
                      },
                      child: Container(
                          padding: EdgeInsets.only(
                              top: 12, bottom: 12, left: 18, right: 18),
                          decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border(
                                  bottom: BorderSide(
                                      color: lightDivider, width: 1.0))),
                          child: Row(children: [
                            Text(
                                _softphone!.echoLimiterEnabled!
                                    ? "Disable Echo Limiter"
                                    : "Enable Echo Limiter",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          ]))),
                  GestureDetector(
                      onTap: () {
                        _softphone!.calibrateEcho();
                        Navigator.pop(context);
                      },
                      child: Container(
                          padding: EdgeInsets.only(
                              top: 12, bottom: 12, left: 18, right: 0),
                          decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border(
                                  bottom: BorderSide(
                                      color: lightDivider, width: 1.0))),
                          child: Row(children: [
                            Text("Calibrate Echo Cancellation",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          ]))),
                  GestureDetector(
                      onTap: () {
                        if (_softphone!.isTestingEcho)
                          _softphone!.stopTestingEcho();
                        else
                          _softphone!.testEcho();
                        Navigator.pop(context);
                      },
                      child: Container(
                          padding: EdgeInsets.only(
                              top: 12, bottom: 12, left: 18, right: 18),
                          decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border(
                                  bottom: BorderSide(
                                      color: lightDivider, width: 1.0))),
                          child: Row(children: [
                            Text(
                                _softphone!.isTestingEcho
                                    ? "Stop Testing Echo"
                                    : "Test Echo",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          ]))),
                ]))));
  }

  _header() {
    UserSettings settings = _fusionConnection!.settings!;
    Iterable<Did> didFilter =
        dynamicDailingDids.where((Did did) => did.did == selectedOutboundDid);
    var callid = settings.dynamicDialingIsActive &&
            settings.isDynamicDialingDept! &&
            didFilter.isNotEmpty
        ? didFilter.first.groupName!
        : settings.myOutboundCallerId!;
    var user = settings.subscriber!.containsKey('user')
        ? settings.subscriber!['user']
        : '';
    return Container(
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: bgBlend),
        padding: EdgeInsets.only(top: 72, left: 18, bottom: 12, right: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              child: ContactCircle.withCoworkerAndDiameter(
                  [settings.myContact()],
                  [],
                  _fusionConnection!.coworkers
                      .lookupCoworker(_fusionConnection!.getUid()),
                  70)),
          Container(
              margin: EdgeInsets.only(top: 18, bottom: 6),
              child: Text(settings.myContact().name,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700))),
          Container(
              margin: EdgeInsets.only(top: 0, bottom: 12),
              child: Text(
                  ("" + callid).formatPhone() + " " + mDash + " x" + user,
                  style: TextStyle(
                      color: translucentWhite(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500)))
        ]));
  }

  _row(String icon, String label, String smallText, Function? onTap, Icon? ico,
      {Widget? trailingWidget, double? labelMaxWidth}) {
    return GestureDetector(
        onTap: onTap as void Function()?,
        child: Container(
            decoration: BoxDecoration(color: Colors.transparent),
            margin: EdgeInsets.only(left: 18, right: 18, top: 12, bottom: 12),
            child: Row(
                crossAxisAlignment: trailingWidget != null
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Container(
                      margin: EdgeInsets.only(right: 24),
                      width: 22,
                      height: 22,
                      child: ico != null
                          ? label == "Log Out" && loggingOut
                              ? CircularProgressIndicator()
                              : ico
                          : Opacity(
                              opacity: icon.contains("call_view") ? 0.45 : 1.0,
                              child: Image.asset(
                                  "assets/icons/" + icon + ".png",
                                  width: 22,
                                  height: 22))),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LimitedBox(
                          maxWidth: labelMaxWidth ?? double.infinity,
                          child: Text(label,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (smallText.length > 0) Container(height: 4),
                        if (smallText.length > 0)
                          Text(smallText,
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                  color: smoke,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400))
                      ]),
                  if (trailingWidget != null)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                            decoration: BoxDecoration(
                                border: Border(
                                    left: BorderSide(width: 1, color: smoke))),
                            // height: 24,
                            child: trailingWidget),
                      ),
                    )
                ])));
  }

  _line() {
    return Container(
        margin: EdgeInsets.only(left: 18, right: 18, top: 0, bottom: 8),
        child: Row(children: [
          Container(margin: EdgeInsets.only(right: 24), width: 20, height: 20),
          horizontalLine(12)
        ]));
  }

  _openOutboundDIDMenu() {
    List<Did> _dids = [];
    _fusionConnection!.dids.getDids(((dids, fromServer) => _dids = dids));
    if (dynamicDailingDids.length > 0) {
      dynamicDailingDids.forEach((element) {
        _dids.add(element);
      });
    }

    _dids.sort((Did a, Did b) => a.did == selectedOutboundDid ||
            (a.did == selectedOutboundDid && a.favorite!) ||
            (a.did == selectedOutboundDid && a.groupName != null)
        ? -1
        : (a.favorite! || (a.groupName != null && !b.favorite!)) &&
                b.did != selectedOutboundDid
            ? -1
            : 1);

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (contact) => PopupMenu(
            label: "Manage Outbound DID",
            bottomChild: Container(
                constraints: BoxConstraints(
                    minHeight: 100,
                    maxHeight: MediaQuery.of(context).size.height - 250,
                    minWidth: 90,
                    maxWidth: MediaQuery.of(context).size.width),
                child: _dids.isEmpty
                    ? Center(
                        child: Text('No Outbound Dids Found',
                            style: TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                                fontWeight: FontWeight.w500)),
                      )
                    : ListView(
                        padding: EdgeInsets.all(8),
                        children: _dids.map((Did option) {
                          return GestureDetector(
                              onTap: () {
                                _fusionConnection!.settings!.setOutboundDid(
                                    option.did!, option.groupName != null);
                                setState(() {
                                  selectedOutboundDid = option.did;
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                  padding: EdgeInsets.only(
                                      top: 12, bottom: 12, left: 18, right: 18),
                                  decoration: BoxDecoration(
                                      color: (option.did == selectedOutboundDid
                                          ? lightHighlight
                                          : Color.fromARGB(0, 0, 0, 0)),
                                      border: Border(
                                          bottom: BorderSide(
                                              color: lightDivider,
                                              width: 1.0))),
                                  child: Row(children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        LimitedBox(
                                          maxWidth: 175,
                                          child: Text(
                                            option.groupName ??
                                                (option.did! + "")
                                                    .formatPhone(),
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        Container(height: 6),
                                        Text(
                                            option.notes!.replaceFirst(
                                                RegExp(r"^ *-[ 0-9]+- *"), ""),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500))
                                      ],
                                    ),
                                    Spacer(),
                                    if (option.did == selectedOutboundDid)
                                      Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      ),
                                    if (option.favorite! &&
                                        option.did != selectedOutboundDid)
                                      Icon(
                                        Icons.star,
                                        color: Colors.white,
                                      ),
                                    if (option.groupName != null &&
                                        option.did != selectedOutboundDid)
                                      Icon(
                                        Icons.bolt,
                                        color: Colors.white,
                                        size: 28,
                                      )
                                  ])));
                        }).toList()))));
  }

  void _editProfilePic() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => PopupMenu(
        label: "Source",
        bottomChild: Container(
          height: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => _selectImage("camera"),
                child: Container(
                  padding: EdgeInsets.only(bottom: 10, top: 14, left: 12),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: lightDivider, width: 1.0))),
                  child: Text(
                    'Camera',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _selectImage("photos"),
                child: Container(
                  padding: EdgeInsets.only(bottom: 10, top: 14, left: 12),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: lightDivider, width: 1.0))),
                  child: Text(
                    'Photos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _uploadPic(XFile image, Contact user) {
    _fusionConnection!.contacts.uploadProfilePic("profile", image, user,
        (Contact contact) {
      setState(() {});
    });
  }

  void _selectImage(String source) {
    final ImagePicker _picker = ImagePicker();
    final Contact user = _fusionConnection!.settings!.myContact();
    if (source == "camera") {
      _picker.pickImage(source: ImageSource.camera).then((XFile? image) {
        setState(() {
          if (image == null) return;
          _uploadPic(image, user);
          Navigator.of(context).pop();
        });
      });
    } else {
      _picker.pickImage(source: ImageSource.gallery).then((XFile? image) {
        if (image == null) return;
        _uploadPic(image, user);
        Navigator.of(context).pop();
      });
    }
  }

  // Future<void> _clearCache() async {
  //   return showDialog<void>(
  //     context: context,
  //     barrierDismissible: false, // user must tap button!
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Clear Cache'),
  //         content: Text('This action will clear all app data in your phone and log you out.'),
  //         actions: <Widget>[
  //           TextButton(
  //             child: Text('Continue', style: TextStyle(color: crimsonDark),),
  //             onPressed: () async {
  //               _fusionConnection.clearCache().then((value){
  //                 if(Platform.isIOS){
  //                   Navigator.of(context).pop();
  //                 }
  //               });
  //             },
  //           ),
  //           TextButton(
  //             child: const Text('Cancel', style: TextStyle(color: Colors.black),),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  Future<void> _savePhoneMyPhoneNumber() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
          return AlertDialog(
            title: const Text('Add Phone Number'),
            content: Wrap(
              runSpacing: 16,
              children: [
                Text(
                    "Please enter a phone number to forward outbound and inbound calls to"),
                TextFormField(
                  initialValue: myPhoneNumber!.formatPhone(),
                  keyboardType: TextInputType.phone,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    InputPhoneFormatter(),
                  ],
                  maxLength: 14,
                  onChanged: (value) {
                    setDialogState(() {
                      setState(() {
                        myPhoneNumber = value.onlyNumbers();
                      });
                    });
                  },
                  style: TextStyle(color: coal),
                  decoration: InputDecoration(
                    counterText: "",
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: smoke)),
                    border: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white)),
                    labelText: "Phone Number",
                    labelStyle: TextStyle(color: smoke),
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(),
                child: Text(
                  'Save',
                  style: TextStyle(
                      color: myPhoneNumber!.length < 10 ? null : crimsonDark),
                ),
                onPressed: myPhoneNumber!.length < 10
                    ? null
                    : () {
                        String uid = _fusionConnection!.getUid();
                        List<SettingsPayload> payload = [
                          SettingsPayload(uid, "uses_carrier",
                              usingCarrierCalls.toString()),
                          SettingsPayload(uid, "cell_phone_number",
                              myPhoneNumber!.onlyNumbers())
                        ];
                        setState(() {
                          userSettings!.updateUserSettings(payload);
                        });
                        if (usingCarrierCalls!) {
                          RegExp fmDevice = RegExp(r'\d{4}(fm)');
                          RegExp allDevices = RegExp(r'(<OwnDevices>)');
                          String devices = "";
                          devices =
                              userSettings!.devices!.replaceAll(allDevices, "");
                          if (userSettings!.devices!.contains(allDevices)) {
                            _fusionConnection!.nsApiCall('device', 'read', {
                              "domain": _fusionConnection!.getDomain(),
                              "user": _fusionConnection!.getExtension()
                            }, callback: (devices) {
                              String devicesString = "";

                              for (var device in devices['device']) {
                                String deviceName = device['aor'].split("@")[0];
                                devicesString +=
                                    " ${deviceName.replaceAll("sip:", "")}";
                              }

                              devicesString =
                                  devicesString.replaceAll(fmDevice, "");

                              _updateAnsweringRule(
                                  forControl: "d",
                                  simControl: "e",
                                  simParams:
                                      "${devicesString.trim()} confirm_${myPhoneNumber!.onlyNumbers()}");
                            });
                          } else {
                            List<String> devicesArray = devices.split(' ');
                            String devicesName = "";
                            for (String device in devicesArray) {
                              if (device.startsWith(';')) continue;
                              if (device.contains(
                                      "${myPhoneNumber!.onlyNumbers()}") &&
                                  !device.startsWith("confirm_")) {
                                if (device.contains(";delay")) {
                                  devicesName +=
                                      " confirm_${device.substring(0, device.indexOf(';'))}";
                                } else {
                                  devicesName += " confirm_$device";
                                }
                                SharedPreferences.getInstance().then((prefs) {
                                  prefs.setString(
                                      "phoneNumberSelected", device);
                                });
                              } else if (device.contains(fmDevice)) {
                                SharedPreferences.getInstance().then((prefs) {
                                  prefs.setString("fmDevice", device);
                                });
                              } else {
                                devicesName += " $device";
                              }
                            }
                            if (!devicesName
                                .contains("${myPhoneNumber!.onlyNumbers()}")) {
                              devicesName +=
                                  " confirm_${myPhoneNumber!.onlyNumbers()}";
                            }

                            _updateAnsweringRule(
                                forControl: "d",
                                simControl: "e",
                                simParams: devices.isNotEmpty
                                    ? devicesName.trim()
                                    : "${_fusionConnection!.getExtension()} confirm_${myPhoneNumber!.onlyNumbers()}");
                          }
                        }
                        Navigator.of(context).pop();
                      },
              ),
              TextButton(
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black),
                ),
                onPressed: () {
                  setState(() {
                    usingCarrierCalls = false;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
      },
    );
  }

  void _updateAnsweringRule(
      {required String forControl,
      required String simControl,
      required String simParams}) {
    String domain = _fusionConnection!.getDomain();
    String ext = _fusionConnection!.getExtension();
    String uid = _fusionConnection!.getUid();
    _fusionConnection!.nsApiCall("answerrule", "read", {
      'domain': domain,
      'user': ext,
    }, callback: (Map<String, dynamic> data) {
      if (data['answering_rule'] != null) {
        String? ruleName = "";

        if (data['answering_rule'][0] == null &&
            data['answering_rule']['time_frame'] != null) {
          ruleName = data['answering_rule']['time_frame'];
        } else {
          for (var rule in data['answering_rule']) {
            if (rule['active'] == "1") {
              ruleName = rule['time_frame'];
              break;
            }
          }
        }

        _fusionConnection!.nsApiCall(
            "answerrule",
            "update",
            {
              "domain": domain,
              "user": ext,
              "uid": uid,
              "time_frame": ruleName,
              "for_control": forControl,
              "sim_control": simControl,
              "sim_parameters": simParams
            },
            callback: (Map data) => {});
      }
    });
  }

  Widget _toggleUseCarrier() {
    return Switch(
        value: usingCarrierCalls!,
        activeColor: crimsonLight,
        inactiveTrackColor: smoke,
        onChanged: ((value) {
          if (usingCarrierCalls!) {
            SettingsPayload payload = SettingsPayload(
                _fusionConnection!.getUid(),
                "uses_carrier",
                value ? value.toString() : "");
            setState(() {
              usingCarrierCalls = value;
              userSettings!.updateUserSettings([payload]);
            });
            if (!value) {
              RegExp answerConfDevice = RegExp(r'(confirm_)\d{10}');
              _fusionConnection!.nsApiCall("device", "read", {
                "domain": _fusionConnection!.getDomain(),
                "user": _fusionConnection!.getExtension()
              }, callback: (devices) {
                String allDevices = "";
                if (devices['device'].length ==
                    userSettings!.devices!
                        .split(" ")
                        .where((element) => element.isNotEmpty)
                        .length) {
                  allDevices = "<OwnDevices>";
                }
                SharedPreferences.getInstance().then((prefs) {
                  String fmDeviceSelected = prefs.getString("fmDevice") ?? "";
                  String phoneNumber =
                      prefs.getString("phoneNumberSelected") ?? "";
                  String devicesString =
                      userSettings!.devices!.replaceAll(answerConfDevice, "");
                  String fm =
                      fmDeviceSelected.isNotEmpty ? "$fmDeviceSelected" : '';
                  String sanitized = "";

                  for (String device in devicesString.split(' ')) {
                    if (device.startsWith(';')) continue;
                    sanitized += " $device";
                  }

                  _updateAnsweringRule(
                      forControl: "d",
                      simControl: "e",
                      simParams: allDevices.isNotEmpty
                          ? "${_fusionConnection!.getExtension()} $allDevices"
                          : "${sanitized} ${fm} ${sanitized.contains(phoneNumber) ? '' : phoneNumber}");

                  if (fmDeviceSelected.isNotEmpty) {
                    prefs.setString("fmDevice", "");
                  }
                  if (phoneNumber.isNotEmpty) {
                    prefs.setString("phoneNumberSelected", "");
                  }
                });
              });
            }
          } else {
            _savePhoneMyPhoneNumber();
            setState(() {
              usingCarrierCalls = value;
            });
          }
        }));
  }

  Widget _toggleDisableCallsSync() {
    return Switch(
        value: disableSyncCallsToIPhone,
        activeColor: crimsonLight,
        inactiveTrackColor: smoke,
        onChanged: ((value) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text("Attention"),
              content: Text(
                  "This action requires closing and reopening the app to take effect"),
              actions: [
                TextButton(
                    onPressed: () {
                      _softphone.setIOSCallsPrefs(value);
                      setState(() {
                        disableSyncCallsToIPhone = value;
                      });
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      "Okay",
                      style: TextStyle(color: crimsonLight),
                    )),
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text("Cancel")),
              ],
            ),
          );
        }));
  }

  Widget _toggleDND() {
    return Switch(
        value: DND!,
        activeColor: crimsonLight,
        inactiveTrackColor: smoke,
        onChanged: (value) => setState(() {
              DND = value;
              SettingsPayload payload = SettingsPayload(
                  _fusionConnection!.getUid(),
                  "fm_on_dnd",
                  value ? value.toString() : "");
              userSettings!.updateUserSettings([payload]);
            }));
  }

  void _performLogout() {
    setState(() {
      loggingOut = true;
    });
    _fusionConnection!.clearCache().then((value) {
      if (Platform.isIOS) {
        Navigator.of(context).pop();
      }
      _fusionConnection!.logOut();
    });
  }

  _body() {
    List<Widget> response = [
      _row("phone_outgoing", "Manage Outbound DID", "", () {
        _openOutboundDIDMenu();
      }, null),

      _row("call_view/audio_phone", "Audio Settings", "", () {
        _onAudioBtnPress();
      }, null),

      _row(
          "",
          "Edit Profile Picture",
          "",
          _editProfilePic,
          Icon(
            Icons.edit,
            color: smoke.withOpacity(0.45),
            size: 26,
          )),

      // _row("", "Clear Cache", "", _clearCache,
      //   Icon(Icons.cached, color: smoke.withOpacity(0.45), size: 26,)),

      _row(
          "",
          "Use Carrier",
          usingCarrierCalls! ? myPhoneNumber!.formatPhone() : "",
          null,
          Icon(
            Icons.phone_forwarded,
            color: smoke.withOpacity(0.45),
            size: 26,
          ),
          trailingWidget: _toggleUseCarrier()),

      _row(
          "",
          "Silence",
          "Mute Calls & Chats",
          null,
          Icon(
            Icons.dark_mode_outlined,
            color: smoke.withOpacity(0.45),
            size: 26,
          ),
          trailingWidget: _toggleDND()),
      if (Platform.isIOS)
        _row(
            "",
            "Disable syncing calls to iPhone",
            usingCarrierCalls! ? myPhoneNumber!.formatPhone() : "",
            null,
            Icon(
              Icons.update_disabled,
              color: smoke.withOpacity(0.45),
              size: 26,
            ),
            trailingWidget: _toggleDisableCallsSync(),
            labelMaxWidth: 150),

      _line(),

      _row("", "Log Out", "", _performLogout,
          Icon(Icons.logout, color: smoke.withOpacity(0.45), size: 26))
    ];
    return response;
  }

  @override
  Widget build(BuildContext context) {
    bool isFusionPlus = _fusionConnection!.settings!.hasFusionPlus();
    return Drawer(
        child: Container(
            decoration: BoxDecoration(
                image: DecorationImage(
                    image: AssetImage("assets/fill.jpg"), fit: BoxFit.cover),
                color: bgBlend),
            child: Column(children: [
              _header(),
              Expanded(
                  child: Container(
                      padding: EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(color: coal),
                      child: ListView(children: _body()))),
              Container(
                  decoration: BoxDecoration(color: coal),
                  padding:
                      EdgeInsets.only(left: 18, right: 18, bottom: 24, top: 12),
                  child: Row(children: [
                    Image.asset("assets/simplii_logo.png",
                        width: 125, height: 18),
                    Expanded(child: Container()),
                    Container(
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(
                            left: 8, right: 8, bottom: 4, top: 4),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                            border: Border.all(color: halfSmoke, width: 1.0)),
                        child: Column(
                          children: [
                            Text(isFusionPlus ? "Fusion Plus" : "Fusion",
                                style: TextStyle(
                                    color: halfSmoke,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              "v." + _softphone!.appVersion!,
                              style: TextStyle(
                                  color: halfSmoke,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            )
                          ],
                        ))
                  ])),
              // SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ])));
  }
}
