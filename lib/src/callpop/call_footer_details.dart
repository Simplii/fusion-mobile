import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/crm_leads_row.dart';
import 'package:fusion_mobile_revamped/src/models/callpop_info.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:sip_ua/sip_ua.dart';

class CallFooterDetails extends StatefulWidget {
  CallFooterDetails(
    this._softphone, 
    this._activeCall,
    this.toggleDisposition,
      {Key? key})
      : super(key: key);

  final Softphone? _softphone;
  final Call? _activeCall;
  final Function toggleDisposition;

  @override
  State<StatefulWidget> createState() => _CallFooterDetailsState();
}

class _CallFooterDetailsState extends State<CallFooterDetails> {
  Function get _toggleDisposition => widget.toggleDisposition;

  @override
  Widget build(BuildContext context) {
    CallpopInfo? info = widget._softphone!.getCallpopInfo(widget._activeCall!.id);

    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(12, 6, 12, iphoneIsLarge() ? 32 : 6),
      alignment: Alignment.center,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (!widget._softphone!.isConnected(widget._activeCall!)) Spacer(),
        Container(
            height: 38,
            constraints: BoxConstraints(
                minWidth: 120,
                maxWidth: MediaQuery.of(context).size.width - 160),
            child: ListView(scrollDirection: Axis.horizontal, children: [
              CrmLeadsRow(widget._softphone, info != null ? info.crmContacts : [])
            ])),
        Spacer(),
        if (widget._softphone!.isConnected(widget._activeCall!))
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ash
            ),
            onPressed: _toggleDisposition as void Function()?, 
            child: Text("Disposition"))
      ]),
    );
  }
}
