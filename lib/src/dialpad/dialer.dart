import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/dialpad/contacts_search.dart';
import 'package:fusion_mobile_revamped/src/dialpad/dialpad.dart';

class Dialer extends StatefulWidget {
  Dialer(this._fusionConnection, this._softphone, {Key? key}) : super(key: key);

  final FusionConnection _fusionConnection;
  final Softphone _softphone;

  @override
  State<StatefulWidget> createState() => _DialerState();
}

class _DialerState extends State<Dialer> {
  FusionConnection get _fusionConnection => widget._fusionConnection;
  Softphone get _softphone => widget._softphone;

  String _dialPadQuery = "";

  _updateDialPadQuery(String newQuery) {
    setState(() {
      _dialPadQuery = newQuery;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(child: ContactsSearch(_fusionConnection, _softphone, "")),
      DialPad(_fusionConnection, _softphone, onQueryChange: _updateDialPadQuery)
    ]);
  }
}
