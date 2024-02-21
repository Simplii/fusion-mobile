import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/contacts/recent_contacts.dart';
import 'package:fusion_mobile_revamped/src/dialpad/dialpad.dart';
import 'package:fusion_mobile_revamped/src/messages/sms_conversation_view.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../backend/fusion_connection.dart';
import '../calls/recent_calls.dart';
import '../components/popup_menu.dart';
import '../styles.dart';
import '../utils.dart';

class TransferCallPopup extends StatefulWidget {
  final FusionConnection _fusionConnection;
  final Softphone _softphone;
  final Function(String to, String type) _onTransfer;
  final Function() _goBack;

  TransferCallPopup(
      this._fusionConnection, this._softphone, this._goBack, this._onTransfer,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _TransferCallpopState();
}

class _TransferCallpopState extends State<TransferCallPopup> with TickerProviderStateMixin {
  FusionConnection get _fusionConnection => widget._fusionConnection;
  Softphone get _softphone => widget._softphone;
  String _query = "";
  TabController? _tabController;

  final List<Tab> tabs = [
    Tab(text: "Recent",height: 30),
    Tab(text: "Contacts",height: 30),
    Tab(text: "Coworkers", height: 30),
  ];

  @override
  initState(){
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  _directTransfer(String to) {
    widget._onTransfer(to, "blind");
  }

  _assistedTransfer(String to) {
    widget._onTransfer(to, "assisted");
  }

  _selectTransferType(Contact? contact, CrmContact? crmContact, String number) {
    void _selectTransfer(String transferType) {
      if (contact != null) {
        transferType == "direct" 
        ? _directTransfer(contact.firstNumber() ?? "") 
        : _assistedTransfer(contact.firstNumber() ?? "");
      } else if (crmContact != null) {
         transferType == "direct" 
        ? _directTransfer(crmContact.firstNumber() ?? "")
        : _assistedTransfer(crmContact.firstNumber() ?? "");
      } else {
         transferType == "direct" 
        ? _directTransfer(number)
        : _assistedTransfer(number);
      }
    }

    return showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext buildContext) => PopupMenu(
              label: 'Transfer type',
              bottomChild: Container(
                constraints: BoxConstraints(
                    minHeight: 100,
                    minWidth: 90,
                    maxWidth: MediaQuery.of(context).size.width - 136,
                    maxHeight: 100),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                            height: 50,
                            width: MediaQuery.of(context).size.width - 136,
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: lightDivider, width: 1.0))),
                            child: TextButton(
                              style: ButtonStyle(
                                alignment: Alignment.centerLeft,
                              ),
                              onPressed: () {
                                _selectTransfer('direct');
                                Navigator.pop(context);
                              },
                              child: Text(
                                "Direct Transfer",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ))
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                            height: 50,
                            width: MediaQuery.of(context).size.width - 136,
                            decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: lightDivider, width: 1.0))),
                            child: TextButton(
                              style: ButtonStyle(
                                alignment: Alignment.centerLeft,
                              ),
                              onPressed: () {
                               _selectTransfer('assisted');
                                Navigator.pop(context);
                              },
                              child: Text(
                                "Assisted Transfer",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ))
                      ],
                    ),
                  ],
                ),
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16))),
        margin: EdgeInsets.only(top: 60),
        child: Column(children: [
          Container(
              margin: EdgeInsets.only(top: 8),
              child: Center(child: popupHandle())),
          TabBar(
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
            labelPadding: EdgeInsets.only(bottom: 5),),
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
                        onSelect: (Contact? contact, CrmContact? crmContact){
                          if (contact != null && contact.firstNumber() != null) {
                            _selectTransferType(contact, null, '');
                          } else if (crmContact != null && crmContact.firstNumber() != null) {
                            _selectTransferType(null, crmContact, '');
                          }
                        },
                      );
                    } else {
                      return ContactsSearchList(_fusionConnection, _softphone, _query, tab.text!.toLowerCase(),
                        embedded: true,
                        onSelect: (Contact? contact, CrmContact? crmContact) {
                          if (contact != null && contact.firstNumber() != null) {
                            _selectTransferType(contact, null, '');
                          } else if (crmContact != null && crmContact.firstNumber() != null) {
                            _selectTransferType(null, crmContact, '');
                          }
                        },
                        fromDialpad: true,);
                      }
                    }
                  ).toList()
                ),
          ),
          DialPad(
            _fusionConnection, 
            widget._softphone, 
            fromTransferScreen: true, 
            directTransfer: _directTransfer,
            onPlaceCall: (String number) {
              _selectTransferType(null, null, number);
            }, 
            onQueryChange: (String query) {
              setState(() {
                _query = query;
              });
            }
          )
        ]));
  }
}
