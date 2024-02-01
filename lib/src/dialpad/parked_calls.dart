import 'dart:async';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/components/crm_leads_row.dart';
import 'package:fusion_mobile_revamped/src/models/callpop_info.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/park_lines.dart';
import 'package:sip_ua/sip_ua.dart';
import '../utils.dart';
import '../styles.dart';

class ParkedCalls extends StatefulWidget {
  ParkedCalls(this._fusionConnection, this._softphone, {Key? key})
      : super(key: key);

  final FusionConnection? _fusionConnection;
  final Softphone? _softphone;

  @override
  State<StatefulWidget> createState() => _ParkedCallsState();
}

class _ParkedCallsState extends State<ParkedCalls> {
  FusionConnection? get _fusionConnection => widget._fusionConnection;
  Call? get _activeCall => _softphone!.activeCall;
  Softphone? get _softphone => widget._softphone;
  List<ParkLine> _parkLines = [];
  int _lookupState = 0;
  late Timer _timer;

  initState() {
    super.initState();
    _timer = new Timer.periodic(
      Duration(seconds: 1),
          (Timer timer) {
        setState(() {});
      },
    );
  }
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  _spinner() {
    return Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(bottom: 24, top: 24, left: 48, right: 48),
        child: Center(child: SpinKitThreeBounce(color: smoke, size: 50)));
  }

  _isSpinning() {
    return _lookupState < 2 && _parkLines.length == 0;
  }

  _lookup() {
    if (_lookupState == 1) return;
    _lookupState = 1;
    _fusionConnection!.parkLines
        .getParks((List<ParkLine> lines, bool fromServer) {
      if (!mounted) return;
      setState(() {
        _parkLines = lines;
      });
    });
  }

  _refresh() {
    _lookupState = 0;
    _lookup();
  }

  Widget _parkRow(ParkLine line, int index) {
    if (!line.isActive!)
      return _emptyParkRow(line, index);
    else
      return _activeParkRow(line, index);
  }

  Widget _callView() {
    CallpopInfo info = _softphone!.getCallpopInfo(_activeCall!.id)!;
    return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ContactCircle.withDiameterAndMargin(info.contacts, info.crmContacts, 64, 8),
          Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  if (info.getCompany(defaul: "")!.trim() != "")
                    Text(info.getCompany()!,
                    style: TextStyle(
                      color: translucentWhite(0.66),
                      fontWeight: FontWeight.w700,
                      fontSize: 14
                    )),
                  Text(
                    info.getName(defaul: "Unknown")!,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900)
                  ),
                  Text(
                    info.phoneNumber!.formatPhone(),
                    style: TextStyle(
                      color: translucentWhite(0.66),
                      fontSize: 12,
                      fontWeight: FontWeight.w700
                    )
                  )
                ]
              )),
          Text(
            _softphone!.getCallRunTimeString(_activeCall!),
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900
            )
          )
        ]
      )
    );
  }

  Widget _emptyParkRow(ParkLine line, int index) {
    return GestureDetector(
        onTap: () {
          if (_activeCall != null) {
            _softphone!.transfer(
                _activeCall!,
                "sip:park_" + line.parkLine.toString() + "@" + _fusionConnection!.getDomain());
            _refresh();
          }

          Navigator.pop(context);
        },
        child: Container(
        margin: EdgeInsets.only(bottom: 16),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: DottedBorder(
                    borderType: BorderType.RRect,
                    radius: Radius.circular(8),
                    padding: EdgeInsets.all(2),
                    dashPattern: [3, 3],
                    color: smoke.withAlpha(128),
                    child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: particle.withAlpha((256 / 3).round()),
                            borderRadius: BorderRadius.all(Radius.circular(8))),
                        child: Row(children: [
                          Spacer(),
                          Text("Space " + index.toString(),
                              style: TextStyle(
                                  color: char,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          Container(
                              margin: EdgeInsets.only(left: 12),
                              padding: EdgeInsets.only(
                                  top: 4, bottom: 4, left: 6, right: 6),
                              decoration: BoxDecoration(
                                  color: particle,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(4))),
                              child: Text(line.parkLine.toString(),
                                  style: TextStyle(
                                      color: char,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700))),
                          Spacer()
                        ]))))
          ])
        ])));
  }

  Widget _activeParkRow(ParkLine line, int index) {
    Coworker? parkedBy =
        _fusionConnection!.coworkers.lookupCoworker(line.parkedBy!);
    return Container(
        margin: EdgeInsets.only(bottom: 16),
        child: Column(children: [
          Row(children: [
            Expanded(
                child: DottedBorder(
                    borderType: BorderType.RRect,
                    radius: Radius.circular(8),
                    dashPattern: [3, 0],
                    color: smoke.withAlpha(128),
                    child: Column(children: [
                      Container(
                          decoration: BoxDecoration(color: Colors.white),
                          padding: EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                            ContactCircle.withDiameterAndMargin(line.contacts, [], 48, 0),
                            Container(width: 12),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                              if (line.contacts!.length > 0 && line.contacts![0].company != "")
                                Text(line.contacts![0].company!,
                                    style: TextStyle(
                                        color:
                                            coal.withAlpha((256 / 3).round()),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              Text(line.contactName(),
                                  style: TextStyle(
                                      color: coal,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18)),
                              Text(line.phone!.formatPhone(),
                                  style: TextStyle(
                                      color: coal.withAlpha((256 / 3).round()),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700))
                            ])),
                            Column(children: [
                              Text(
                                  DateTime.now()
                                      .difference(line.timeParked)
                                      .inSeconds
                                      .printDuration(),
                                  style: TextStyle(
                                      color: coal,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              Container(
                                  decoration: BoxDecoration(
                                      color: informationBlue,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(8))),
                                  padding: EdgeInsets.only(
                                      top: 4, left: 6, bottom: 4, right: 6),
                                  child: Text(line.parkLine.toString(),
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)))
                            ])
                          ])),
                      Container(
                          decoration: BoxDecoration(color: particle),
                          height: 1),
                      Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: particle.withAlpha((256 / 3).round())),
                          child: Column(children: [
                            if (parkedBy != null)
                              Row(children: [
                                ContactCircle.withCoworkerAndDiameter(
                                    [], [], parkedBy, 24),
                                Text("Parked by " + parkedBy.getName(),
                                    style: TextStyle(
                                        color: char,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400))
                              ]),
                            if (line.notes != null &&
                                line.notes!.trim().length > 0)
                              Container(
                                  padding: EdgeInsets.only(top: 6, left: 30),
                                  child: Text(line.notes!,
                                      maxLines: 10,
                                      style: TextStyle(
                                          color: char,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500))),
                            Row(children: [
                              //CrmLeadsRow(_softphone)
                              Spacer(),
                              GestureDetector(
                                  onTap: () {
                                    _fusionConnection!.apiV2Call(
                                        "get",
                                        "/calls/parkLines/" + line.parkLine.toString() + "/pickUp", {});
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                      margin: EdgeInsets.only(top: 12),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(4)),
                                          border: Border.all(
                                              color: particle, width: 2)),
                                      padding: EdgeInsets.only(
                                          top: 12,
                                          bottom: 12,
                                          left: 12,
                                          right: 16),
                                      child: Row(children: [
                                        Image.asset(
                                            "assets/icons/phone_green.png",
                                            width: 20,
                                            height: 20),
                                        Container(width: 6),
                                        Text("TAKE CALL",
                                            style: TextStyle(
                                                color: char,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900))
                                      ])))
                            ])
                          ]))
                    ])))
          ])
        ]));
  }

  @override
  Widget build(BuildContext context) {
    if (_lookupState == 0) {
      _lookup();
    }

    return Container(
      child: Column(
        children: [
          Center(
              child: Text('Parked Calls',
                  style: TextStyle(
                      color: coal, fontSize: 16, fontWeight: FontWeight.w700))),
          Expanded(
              child: Container(
                  margin: EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(8))),
                  child: _isSpinning()
                      ? _spinner()
                      : ListView.builder(
                          itemCount: _parkLines.length,
                          itemBuilder: (BuildContext context, int index) {
                            return _parkRow(_parkLines[index], index + 1);
                          },
                          padding:
                              EdgeInsets.only(left: 12, right: 12, top: 12))))
        ],
      ),
    );
  }
}
