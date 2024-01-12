import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';

class DateTimePicker extends StatefulWidget {
  final double height;
  final bool iosStyle;

  final Function(DateTime?) onComplete;
  DateTimePicker({ 
    required this.height, 
    required this.onComplete, 
    this.iosStyle = false ,
    Key? key}) : super(key: key);

  @override
  State<DateTimePicker> createState() => _DateTimePickerState();
}

class _DateTimePickerState extends State<DateTimePicker> {
  double get _height => widget.height;
  Function(DateTime?) get _onComplete => widget.onComplete;
  bool get _iosStyle => widget.iosStyle;
  TimeOfDay? selectedTime;
  DateTime? selectedDate;
  DateTime? iosDateTime;

  Future _openTimePicker () async {
    TimeOfDay? time = await showTimePicker(
      context: context, 
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    setState(() {
      selectedTime = time;
    });
  }
  
  Future _openDatePicker () async {
    DateTime? date = await showDatePicker(
      context: context, 
      initialDate:  DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050)
    );
    setState(() {
      selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _iosStyle 
          ? [ 
              SizedBox(
                height: 180,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                      brightness: Brightness.dark,
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.dateAndTime,
                    onDateTimeChanged: (value){
                      setState(() {
                        iosDateTime = value;
                      });
                    },
                    minimumDate: DateTime.now(),
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric( horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: lightDivider, width: 1.0), 
                    top: BorderSide(color: lightDivider, width: 1.0)
                  )
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.all(10),
                  ),
                  onPressed: (){
                    if(iosDateTime != null){
                      _onComplete(iosDateTime);
                      Navigator.of(context).pop();
                    }
                  }, 
                  child: Text("Schedule",style: TextStyle(
                      fontSize: 18,
                      color: iosDateTime != null
                        ? Colors.white
                        : null,
                      fontWeight: FontWeight.w600 
                    ),)
                ),
              )
            ]
          : 
            [
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.all(20)),
                icon: Icon(Icons.schedule,color: selectedTime != null
                      ? Colors.white
                      : null ),
                onPressed: _openTimePicker, 
                label: Text(
                  selectedTime?.format(context) ?? TimeOfDay.now().format(context),
                  style: TextStyle(
                    fontSize: 24,
                    color: selectedTime != null
                      ? Colors.white
                      : null 
                  ),
                )
              ),
              TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.all(20)),
                icon: Icon(
                  Icons.calendar_month, 
                  color: selectedDate != null
                    ? Colors.white
                    : null ,
                ),
                onPressed: _openDatePicker, 
                label: Text(
                  DateFormat.yMMMd().format(selectedDate ?? DateTime.now()),
                  style: TextStyle(
                    fontSize: 24,
                    color: selectedDate != null
                      ? Colors.white
                      : null 
                  ),
                )
              ),
              Container(
                margin: EdgeInsets.symmetric( horizontal: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: lightDivider, width: 1.0), 
                    top: BorderSide(color: lightDivider, width: 1.0)
                  )
                ),
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.all(10)),
                  onPressed: (){
                    if(selectedDate !=null && selectedTime != null){
                      _onComplete(DateTime(selectedDate!.year,selectedDate!.month,selectedDate!.day, selectedTime!.hour,selectedTime!.minute));
                      Navigator.of(context).pop();
                    }
                  }, 
                  child: Text("Schedule",style: TextStyle(
                      fontSize: 17,
                      color: selectedTime != null && selectedDate != null
                        ? Colors.white
                        : null,
                      fontWeight: FontWeight.w600
                    ),)
                ),
              )
            ],
      ),
    );
  }
}