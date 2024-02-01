import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:intl/intl.dart';
import '../styles.dart';

class DialpadRecentCalls extends StatefulWidget {
  final Contact? contact;
  final CrmContact? crmContact;
  final Softphone? softphone;
  final DateTime? date;
  final Function(Contact? contact,CrmContact? crmContact)? onSelect;
  const DialpadRecentCalls({
    Key? key,
    required this.contact,
    required this.crmContact, 
    required this.softphone,
    required this.date,
    this.onSelect
  }) : super(key: key);

  @override
  State<DialpadRecentCalls> createState() => _DialpadRecentCallsState();
}

class _DialpadRecentCallsState extends State<DialpadRecentCalls> {
  Contact? get _contact => widget.contact;
  CrmContact? get _crmContact => widget.crmContact;
  Softphone? get _softphone => widget.softphone;
  DateTime? get _date => widget.date;
  Function(Contact? contact,CrmContact? crmContact)? get _onSelect => widget.onSelect;

  _relativeDateFormatted(DateTime calcDate) {
    final todayAndYesterdayFmt = new DateFormat("h:mm a");
    final olderThanYesterdayFmt = new DateFormat("M/d h:mm a");
    final today = DateTime.now();
    final lastMidnight = new DateTime(today.year, today.month, today.day);

    if (lastMidnight.isBefore(calcDate)) {
      return "Today " + todayAndYesterdayFmt.format(calcDate);
    } else if (lastMidnight.subtract(new Duration(days: 1)).isBefore(calcDate)) {
      return "Yesterday " + todayAndYesterdayFmt.format(calcDate);
    } else {
      return olderThanYesterdayFmt.format(calcDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (){
        if(_onSelect != null){
          if(_contact != null){
            _onSelect!(_contact,null);
          }else if(_crmContact != null){
            _onSelect!(null,_crmContact);
          }
        } else {
          if(_contact != null){
            _softphone!.makeCall(_contact!.firstNumber());
          } else if(_crmContact != null){
            _softphone!.makeCall(_crmContact!.firstNumber());
          }
          Navigator.of(context).pop();
        }
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical:4 ,horizontal: 8),
        child: Row(
          children: [
            ContactCircle.withDiameter([_contact], [], 46),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _contact?.name ?? "Unknown", 
                  style: TextStyle(
                    color: coal,
                    fontSize: 14,
                    fontWeight: FontWeight.w700
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Color.fromARGB(255, 243, 242, 242),
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                  child: Wrap(
                    spacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Image.asset("assets/icons/phone_outgoing.png", width: 10, height: 10),
                      Text(
                        _contact!.firstNumber().toString().formatPhone() 
                        + " " + 
                        mDash 
                        + " " +
                        _relativeDateFormatted(_date!),
                        style: TextStyle(
                          color: coal,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w400
                        ),
                      ),
                    ],
                  ),
                )
              ],
            )
          ],
        ),
      )
    );
  }
}