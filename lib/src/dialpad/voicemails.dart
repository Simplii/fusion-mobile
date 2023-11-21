import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/contacts/contact_profile_view.dart';
import 'package:fusion_mobile_revamped/src/messages/sms_conversation_view.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/models/voicemails.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import "../utils.dart";
import '../styles.dart';

class Voicemails extends StatefulWidget {
  Voicemails(this._fusionConnection, this._softphone, {Key key})
      : super(key: key);

  final FusionConnection _fusionConnection;
  final Softphone _softphone;

  @override
  State<StatefulWidget> createState() => _VoicemailsState();
}

class _VoicemailsState extends State<Voicemails> {
  FusionConnection get _fusionConnection => widget._fusionConnection;

  Softphone get _softphone => widget._softphone;
  List<Voicemail> _voicemails = [];
  int _lookupState = 0;
  String _openVmId = "";
  int _audioPosition = 0;
  AudioPlayer _audioPlayer = AudioPlayer();
  String _playingUrl = null;
  bool _isPlaying = false;
  bool _loading = false;

  initState() {
    _audioPlayer.positionStream.listen((Duration event) {
      setState(() {
        _audioPosition = event.inSeconds;
      });
    });
    _audioPlayer.playerStateStream.listen((event) {
      if (event.playing) {
        setState(() {
          _isPlaying = true;
        });
      }
      if (event.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  _spinner() {
    return Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(bottom: 24, top: 24, left: 48, right: 48),
        child: Center(child: SpinKitThreeBounce(color: smoke, size: 50)));
  }

  _isSpinning() {
    return _lookupState < 2;
  }

  _lookup() {
    if (!mounted) return;
    if (_lookupState == 1) return;
    _lookupState = 1;

    _fusionConnection.voicemails
        .getVoicemails((List<Voicemail> vms, bool fromServer) {
      if (!mounted) return;
      setState(() {
            _lookupState = 2;
            _voicemails = vms;
          });
    });
  }

  _toggleOpenVm(Voicemail vm) {
    setState(() {
      if (_openVmId == vm.id)
        _openVmId = null;
      else
        _openVmId = vm.id;
      _audioPosition = 0;
    });
  }

  _pause() {
    _audioPlayer.pause();
    setState(() {
      _isPlaying = false;
    });
  }

  _play(url) {
    if (_playingUrl != url) {
      _audioPlayer.setUrl(url);
      _playingUrl = url;
    }
    _audioPlayer.play();
  }

  _isVmOpen(Voicemail vm) {
    return _openVmId == vm.id;
  }

  _openProfile(Voicemail vm) {
    if (vm.contacts.length > 0)
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => ContactProfileView(
              _fusionConnection, _softphone, vm.contacts[0],null));
  }

  _makeCall(Voicemail vm) {
    _softphone.makeCall(vm.phoneNumber);
  }

  _openMessage(Voicemail vm) async {
    setState(() {
      _loading = true;
    });
    SMSDepartment dept = _fusionConnection.smsDepartments.getDepartment(vm.phoneNumber.length > 6 
      ? DepartmentIds.Personal
      : DepartmentIds.FusionChats
    );

    if(dept.numbers.isEmpty){
      _fusionConnection.smsDepartments.getDepartments((List<SMSDepartment> dep) {
        for (SMSDepartment d in dep) {
          if(d.numbers.isNotEmpty){
            dept = d;
            break;
          }
        }
      });
      if(dept.numbers.isEmpty){
        return showModalBottomSheet(
          context: context,
          backgroundColor: coal,
          shape: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          builder: (context)=> Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height / 3,
            ),
            child: Center(
              child: Text("No personal/departmens SMS number found for this account", 
                style: TextStyle(color: Colors.white),),
            ),
          )).whenComplete(() =>  setState(() {
            _loading = false;
          }));
      }
    }
    SMSConversation convo = await _fusionConnection.messages.checkExistingConversation(
      DepartmentIds.Personal,
      dept.numbers[0],
      [vm.phoneNumber],
      vm.contacts
    );

    setState(() {
      _loading = false;
    });
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
          SMSConversation displayingConvo = convo;
          return SMSConversationView(
            fusionConnection: _fusionConnection, 
            softphone: _softphone, 
            smsConversation: displayingConvo, 
            deleteConvo: null,
            setOnMessagePosted: null,
            changeConvo: (SMSConversation UpdatedConvo){
              setState(() {
                displayingConvo = UpdatedConvo;
              },);
            }
          );
          },
        ),
      );
  }

  Widget _vmRow(Voicemail vm) {
    return Container(
        margin: EdgeInsets.only(bottom: 18),
        child: Column(children: [
          Row(children: [
            ContactCircle.withCoworkerAndDiameter(vm.contacts, [], vm.coworker, 40),
            Container(width: 6),
            Expanded(
                child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(vm.contactName(),
                    style: TextStyle(
                        color: coal,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.4)),
                Spacer(),
                Text(
                    vm.time.month.toString() +
                        "/" +
                        vm.time.day.toString() +
                        "/" +
                        vm.time.year.toString().substring(2),
                    style: TextStyle(
                        color: char, fontSize: 13, fontWeight: FontWeight.w400))
              ]),
              Row(children: [
                Text(vm.phoneNumber.formatPhone(),
                    style: TextStyle(
                        color: char,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        height: 1.4)),
                Spacer(),
                Text(vm.duration.printDuration(),
                    style: TextStyle(
                        color: char.withAlpha((255 * 0.66).round()),
                        fontSize: 13,
                        fontWeight: FontWeight.w400))
              ])
            ])),
            GestureDetector(
                onTap: () {
                  _toggleOpenVm(vm);
                },
                child: Container(
                    decoration: clearBg(),
                    padding: EdgeInsets.all(12),
                    child: Image.asset(
                        _isVmOpen(vm)
                            ? "assets/icons/chevron-up.png"
                            : "assets/icons/chevron-down.png",
                        width: 12,
                        height: 6)))
          ]),
          if (_isVmOpen(vm)) Container(height: 8),
          if (_isVmOpen(vm))
            Row(children: [
              Container(width: 46),
              Expanded(
                  child: Container(
                      decoration: BoxDecoration(
                          color: offWhite,
                          borderRadius: BorderRadius.only(
                              topRight: Radius.circular(8),
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8))),
                      padding: EdgeInsets.all(1),
                      child: Container(
                          padding: EdgeInsets.only(
                              left: 12, top: 12, right: 12, bottom: 18),
                          decoration: BoxDecoration(
                              color: particle,
                              borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                  bottomRight: Radius.circular(8))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    margin: EdgeInsets.only(bottom: 8),
                                    child: Text(
                                        DateFormat('EEE, MMMM d ')
                                                .format(vm.time) +
                                            mDash +
                                            DateFormat(' hh:mm ')
                                                .format(vm.time),
                                        style: TextStyle(
                                            color: smoke,
                                            fontSize: 10,
                                            height: 1.2,
                                            fontWeight: FontWeight.w700))),
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                          onTap: () {
                                            if (_isPlaying)
                                              _pause();
                                            else
                                              _play(vm.path);
                                          },
                                          child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(30)),
                                                border: Border.all(
                                                    width: 2.0, color: smoke),
                                              ),
                                              width: 22,
                                              height: 22,
                                              alignment: Alignment.center,
                                              child:
                                              _isPlaying
                                                  ? Icon(CupertinoIcons.pause,

                                              size: 12, color: smoke)
                                                  : Image.asset(
                                                  "assets/icons/audio-play.png",
                                                  width: 6,
                                                  height: 8))),
                                      Expanded(
                                          child: Stack(children: [
                                        Container(
                                            decoration: BoxDecoration(
                                                color: smoke,
                                                borderRadius: BorderRadius.all(
                                                    Radius.circular(2))),
                                            height: 3,
                                            margin: EdgeInsets.only(
                                                top: 10, bottom: 8, left: 8)),
                                        Container(
                                            margin: EdgeInsets.only(
                                                top: 18, left: 8),
                                            child: Row(children: [
                                              Text(
                                                  _audioPosition
                                                      .printDuration(),
                                                  style: TextStyle(
                                                      color: char,
                                                      fontSize: 10,
                                                      height: 1.2,
                                                      fontWeight:
                                                          FontWeight.w400)),
                                              Spacer(),
                                              Text(vm.duration.printDuration(),
                                                  style: TextStyle(
                                                      color: char,
                                                      fontSize: 10,
                                                      height: 1.2,
                                                      fontWeight:
                                                          FontWeight.w400))
                                            ])),
                                        Container(
                                            alignment: FractionalOffset(
                                                (_audioPosition /
                                                      vm.duration),
                                                0),
                                            child: Container(
                                            margin: EdgeInsets.only(
                                                top: 2, left: 8),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  border: Border.all(
                                                      width: 2.0, color: coal),
                                                  borderRadius:
                                                      BorderRadius.all(
                                                          Radius.circular(8))),
                                              width: 16,
                                              height: 16,
                                            )))
                                      ]))
                                    ]),
                                Container(height: 12),
                                Row(children: [
                                  actionButton("Profile", "user_dark", 18, 18,
                                      () {
                                    _openProfile(vm);
                                  },
                                      opacity:
                                          vm.contacts.length > 0 ? 1.0 : 0.35),
                                  actionButton("Call", "phone_dark", 18, 18,
                                      () {
                                    _makeCall(vm);
                                  }),
                                  actionButton(
                                      "Message", "message_dark", 18, 18, () {
                                    _openMessage(vm);
                                  },isLoading: _loading)
                                ])
                              ]))))
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
              child: Text('Voicemails',
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
                      : _voicemails.length > 0 ? ListView.builder(
                      itemCount: _voicemails.length,
                      itemBuilder: (BuildContext context, int index) {
                        return _vmRow(_voicemails[index]);
                      },
                      padding:
                      EdgeInsets.only(left: 12, right: 12, top: 12)) : Center(child: Text("No Voicemails", style: TextStyle(fontSize: 18, color: Colors.black54)))))
        ],
      ),
    );
  }
}
