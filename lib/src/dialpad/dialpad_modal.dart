import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/contacts/recent_contacts.dart';
import 'package:fusion_mobile_revamped/src/dialpad/contacts_search.dart';
import 'package:fusion_mobile_revamped/src/dialpad/dialer.dart';
import 'package:fusion_mobile_revamped/src/dialpad/dialpad.dart';
import 'package:fusion_mobile_revamped/src/dialpad/parked_calls.dart';
import 'package:fusion_mobile_revamped/src/dialpad/voicemails.dart';
import 'package:fusion_mobile_revamped/src/models/callpop_info.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:fusion_mobile_revamped/src/calls/recent_calls.dart';
class DialPadModal extends StatefulWidget {
  DialPadModal(this._fusionConnection, this._softphone, {Key? key, this.initialTab})
      : super(key: key);

  final FusionConnection _fusionConnection;
  final Softphone _softphone;
  final int? initialTab;

  @override
  State<StatefulWidget> createState() => _DialPadModalState();
}

class _DialPadModalState extends State<DialPadModal>
    with TickerProviderStateMixin {
  FusionConnection get _fusionConnection => widget._fusionConnection;
  Call? get _activeCall => _softphone.activeCall;
  Softphone get _softphone => widget._softphone;
  TabController? _tc;
  int? _initialIndex = 1;
  int? _tabIndex = 1;
  String _query = "";
  Timer? _timer;
  bool v2Domain = false;
  
  final List<Tab> tabs = [
    Tab(text: "Recent",height: 30),
    Tab(text: "Contacts",height: 30),
    Tab(text: "Coworkers", height: 30),
  ];
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
     _tabController = TabController(length: tabs.length, vsync: this);
    _timer = new Timer.periodic(
      Duration(seconds: 1),
      (Timer timer) {
        setState(() {});
      },
    );
    if (widget.initialTab != null)
      _initialIndex = widget.initialTab;
    _tabIndex = _initialIndex;

    _tc =
        new TabController(length: 3, initialIndex: _initialIndex!, vsync: this);
    _tc!.addListener(_updateTabIndex);
    v2Domain = _fusionConnection!.settings!.isV2User();
  }

  @override
  void dispose() {
    super.dispose();
    _tc!.dispose();
    _timer!.cancel();
    _tabController!.dispose();
  }

  void _onTabTapped(int index) {
    _tc!.animateTo(index);
  }

  void _updateTabIndex() {
    setState(() {
      _tabIndex = _tc!.index;
    });
  }

  Widget body() {
    return Container(
      padding: EdgeInsets.only(top: 24),
        child: TabBarView(
      controller: _tc,
      children: [
        Container(
          child: ParkedCalls(_fusionConnection, _softphone),
        ),
        Container(
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(width: 1.5, color: ash)
                  )
                ),
                child: TabBar(
                  unselectedLabelColor: Colors.black,
                  unselectedLabelStyle: TextStyle(
                    fontWeight: FontWeight.normal
                  ),
                  indicatorColor: crimsonDark,
                  tabs: tabs,
                  controller: _tabController,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelPadding: EdgeInsets.only(bottom: 5),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: tabs.map((Tab tab){
                    if(tab.text == "Recent"){
                      return RecentCallsList(
                        _fusionConnection, 
                        _softphone, 
                        tab.text, 
                        "all",
                        query: _query,
                        fromDialpad: true,
                      );
                    } else {
                      return ContactsSearchList(_fusionConnection, _softphone, _query, tab.text!.toLowerCase(),
                        v2Domain,
                        embedded: true,
                        onSelect: (Contact? contact, CrmContact? crmContact) {
                          if (contact != null && contact.firstNumber() != null) {
                            _softphone.makeCall(contact.firstNumber());
                            Navigator.pop(context);
                          } else if (crmContact != null && crmContact.firstNumber() != null) {
                            _softphone.makeCall(crmContact.firstNumber());
                            Navigator.pop(context);
                          }
                        },
                        fromDialpad: true,);
                      }
                    }
                  ).toList()
                ),
              ),
            DialPad(_fusionConnection, _softphone, onQueryChange: (String s) {
              setState(() {
                _query = s;
              });
            })
          ]),
        ),
        Container(
          constraints: BoxConstraints.tightFor(height: 725),
          child: Voicemails(_fusionConnection, _softphone),
        )
      ],
    ));
  }

  Widget navBar() {
    return Container(
        height: 60,
        decoration: BoxDecoration(
            color: particle),
        padding: EdgeInsets.only(top: 0, left: 16, right: 16, bottom: 0),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                  child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(
                          color: _tabIndex == 0
                              ? crimsonLight
                              : Colors.transparent,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(2),
                            bottomRight: Radius.circular(2),
                          )))),
              Expanded(
                  child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(
                          color: _tabIndex == 1
                              ? crimsonLight
                              : Colors.transparent,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(2),
                            bottomRight: Radius.circular(2),
                          )))),
              Expanded(
                  child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(
                          color: _tabIndex == 2
                              ? crimsonLight
                              : Colors.transparent,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(2),
                            bottomRight: Radius.circular(2),
                          ))))
            ]),
            BottomNavigationBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedItemColor: crimsonDarker,
              unselectedItemColor: coal,
              onTap: _onTabTapped,
              currentIndex: _tc != null ? _tc!.index : 1,
              iconSize: 20,
              selectedLabelStyle: TextStyle(
                  color: crimsonDarker,
                  height: 2, fontSize: 10, fontWeight: FontWeight.w700),
              unselectedLabelStyle: TextStyle(
                  color: coal,
                  height: 2, fontSize: 10, fontWeight: FontWeight.w700),
              items: [
              BottomNavigationBarItem(
                  icon: Image.asset("assets/icons/call_view/toolbar/park_inactive.png", width: 13.6, height: 20),
                  activeIcon: Image.asset("assets/icons/call_view/toolbar/park_active.png", width: 13.6, height: 20),

                  label: "Parked Calls",
                ),
                BottomNavigationBarItem(
                    icon: Image.asset("assets/icons/call_view/toolbar/dialpad_inactive.png", width: 17.45, height: 20),
                    activeIcon: Image.asset("assets/icons/call_view/toolbar/dialpad_active.png", width: 17.45, height: 20),
                    label: 'Dial Pad'),
                BottomNavigationBarItem(
                  icon: Image.asset("assets/icons/call_view/toolbar/voicemail_inactive.png", width: 22, height: 20),
                  activeIcon: Image.asset("assets/icons/call_view/toolbar/voicemail_active.png", width: 22, height: 20),
                    label: 'Voicemails')
              ],
            )
          ],
        ));
  }

  Widget _callView() {
    CallpopInfo? info = _softphone.getCallpopInfo(_activeCall!.id);
    if (info == null)
      return Container();
    else
    return Container(
      padding: EdgeInsets.only(left: 18, right: 18, bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ContactCircle.withDiameterAndMargin(info.contacts, info.crmContacts, 64, 8),
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (info.getCompany(defaul: "")!.trim() != "")
                    Text(info.getCompany()!,
                    style: TextStyle(
                      color: translucentWhite(0.66),
                      fontWeight: FontWeight.w700,
                      fontSize: 14
                    )),
                  if (!(info.getCompany(defaul: "")!.trim() != ""))
                    Text(" ",
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
            _softphone.getCallRunTimeString(_activeCall!),
            style: TextStyle(
              height: 1.0,
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900
            )
          )
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Container(
          decoration: BoxDecoration(color: coal.withAlpha(140)),
            child:Column(
        children: [
          Container(height: 60),
          if (_tabIndex == 0 && _activeCall != null)
            _callView(),
          Expanded(child: Container(
            decoration: BoxDecoration(
                color: particle,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8), topRight: Radius.circular(8))),
            child: Container(
                decoration: BoxDecoration(
                    color: particle,
                    borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8))),
                child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Column(children: [
                        Expanded(
                            child: body()),
                        Container(
                            decoration: BoxDecoration(color: coal),
                            child: navBar())]),
                      Container(
                          alignment: Alignment.topCenter,
                          height: 8,
                          width: 80,
                          margin: EdgeInsets.all(8),
                          child: Center(child: popupHandle()))
                    ]))))])));
  }
}
