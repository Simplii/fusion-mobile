import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/popup_menu.dart';
import 'package:fusion_mobile_revamped/src/models/callpop_info.dart';
import 'package:fusion_mobile_revamped/src/models/disposition.dart';
import 'package:fusion_mobile_revamped/src/models/user_settings.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:sip_ua/sip_ua.dart';

import '../styles.dart';

class DispositionListView extends StatefulWidget {
  final Softphone? softphone;
  final FusionConnection? fusionConnection;
  final Call? call;
  final String? phoneNumber;
  final Function onDone;
  final bool fromCallView;
  const DispositionListView({
    required this.softphone,
    required this.fusionConnection,
    required this.call,
    required this.phoneNumber,
    required this.onDone,
    required this.fromCallView,
    Key? key
  }) : super(key: key);

  @override
  State<DispositionListView> createState() => _DispositionListViewState();
}

class _DispositionListViewState extends State<DispositionListView> {
  FusionConnection? get _fusionConnection => widget.fusionConnection;
  Softphone? get _softphone => widget.softphone;
  Call? get _call => widget.call;
  String? get _phoneNumber => widget.phoneNumber;
  bool get _fromCallView => widget.fromCallView;
  UserSettings? get settings => widget.fusionConnection!.settings;
  Function get _onDone => widget.onDone;
  final _formKey = GlobalKey<FormState>();
  bool _showError = false;
  Disposition? _selectedDisposition;
  List<CallType> _callTypes = [];
  bool _callTypeEnabled = false;
  List<DispositionCustomField> dispositionCustomFields = [];
  CallType? _selectedCallType;
  Map<String,dynamic>? _fieldValues = {};
  String? _notes = "";

  @override
  initState(){
    super.initState();
    _notes = _softphone!.getCallDispositionData(_call!.id, "dispositionNotes");
    _selectedDisposition = _softphone!.getCallDispositionData(_call!.id, "selectedDisposition");
    _selectedCallType = _softphone!.getCallDispositionData(_call!.id, "selectedCallType");
    _fieldValues = _softphone!.getCallDispositionData(_call!.id, "fieldValues");
    _callTypeEnabled = settings!.isFeatureEnabled("Hubspot");
    List<dynamic> schema = settings!.options["schema"];
    schema.where((element) => element['object_type'] == "call_disposition").toList();
    if(schema.isNotEmpty){
      for (var element in schema) {
        for (var customField in element['custom_fields']) {
          dispositionCustomFields.add(
            DispositionCustomField.fromJson(customField)
          );
        }
      }
    }
    if(settings!.isFeatureEnabled("Hubspot")){
      _getCallTypes();
    }
  }

  Future<void> _getCallTypes() async {
    List<CallType> callTypesList = [];
    await _fusionConnection!.apiV2Call("get", "/dispositions/group/-2/dispositions", {},
      callback: (Map<String,dynamic> data){
        if(data["items"] != null){
          for (Map<String,dynamic> item in data["items"]) {
            callTypesList.add(CallType.fromJson(item));
          }
        }
      }
    );
    setState(() {
      _callTypes = callTypesList;
    });
  }

  List<DispositionGroup> _dispositionOptions() {
    List<DispositionGroup> options = [];
    CallpopInfo? info = _softphone!.getCallpopInfo(_call!.id);

    if (info == null || info.dispositionGroups == null)
      return options;
    else {
      List<Map<String, dynamic>> dispositionGroups = info.dispositionGroups!.cast<Map<String, dynamic>>();
      for (Map<String, dynamic> group in dispositionGroups) {
        DispositionGroup dispoGroup = DispositionGroup(
          id: group["id"].toString(),
          name: group["name"]
        );
        for (Map<String, dynamic> dispo in group["dispositions"]) {
          Disposition dispoObj = Disposition.fromJson(dispo);
          dispoGroup.dispositions.add(dispoObj);
          options.add(dispoGroup);
        }
      }
      return options;
    }
  }

  void _openSelectDispo() {
    List<DispositionGroup> groups = _dispositionOptions();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (contact) => PopupMenu(
        label: "Dispositions",
        bottomChild: Container(
          height: MediaQuery.of(context).size.height / 2,
          child: groups.isNotEmpty 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical:10.0),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.33),
                            borderRadius: BorderRadius.circular(2)
                          ),
                          child: Text(
                            groups[0].name!.toUpperCase(), 
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w700
                            ),)),
                      ],
                    ),
                  ),
                  if(groups[0].dispositions.isNotEmpty)
                    LimitedBox(
                      maxHeight: (MediaQuery.of(context).size.height / 2) - 50,
                      child: ListView.separated(
                        padding: EdgeInsets.only(left: 4),
                        itemCount: groups[0].dispositions.length,
                        separatorBuilder: (context, index) => Container(
                          padding: EdgeInsets.zero,
                          height: 1, 
                          width: double.infinity, 
                          color: halfSmoke
                        ),
                        itemBuilder: (BuildContext context,int index) {
                          return TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 0,vertical: 10),
                              alignment: Alignment.centerLeft,
                            ),
                            onPressed: () => {
                              setState(() {
                                _showError = false;
                                _softphone!.setCallDispositionData(
                                  callId: _call!.id, 
                                  name: "selectedDisposition",
                                  selectedDisposition: groups[0].dispositions[index]
                                );
                                _selectedDisposition = groups[0].dispositions[index];
                                Navigator.of(context).pop();
                              },)
                            },
                            child: Text(
                              groups[0].dispositions[index].label!,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: offWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w600
                              ),
                            ),
                          );
                        },
                      ),
                    )
                ],
              )
            : Center(child: Text("No Dispositions Found", style: TextStyle(color: ash),),) 
        )
      )
    );
  }

  void _openCallType(){
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (contact) => PopupMenu(
        label: "Dispositions",
        bottomChild: Container(
          height: MediaQuery.of(context).size.height / 2,
          child: _callTypes.isNotEmpty 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical:10.0),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.33),
                            borderRadius: BorderRadius.circular(2)
                          ),
                          child: Text(
                            "Hubspot call types", 
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w700
                            ),)),
                      ],
                    ),
                  ),
                  if(_callTypes.isNotEmpty)
                    LimitedBox(
                      maxHeight: (MediaQuery.of(context).size.height / 2) - 50,
                      child: ListView.separated(
                        padding: EdgeInsets.only(left: 4),
                        itemCount: _callTypes.length,
                        separatorBuilder: (context, index) => Container(
                          padding: EdgeInsets.zero,
                          height: 1, 
                          width: double.infinity, 
                          color: halfSmoke
                        ),
                        itemBuilder: (BuildContext context,int index) {
                          return TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 0,vertical: 10),
                              alignment: Alignment.centerLeft,
                            ),
                            onPressed: () => {
                              setState(() {
                                _softphone!.setCallDispositionData(
                                  callId: _call!.id, 
                                  name: "selectedCallType",
                                  selectedCallType: _callTypes[index]
                                );
                                _selectedCallType = _callTypes[index];
                                Navigator.of(context).pop();
                              },)
                            },
                            child: Text(
                              _callTypes[index].label!,
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: offWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w600
                              ),
                            ),
                          );
                        },
                      ),
                    )
                ],
              )
            : Center(child: Text("No Dispositions Found", style: TextStyle(color: ash),),) 
        )
      )
    );
  }

  List<Widget> renderCustomFields(){
    List<Widget> customFields = [];
    if(_selectedDisposition == null) {
      return customFields;
    }
    
    for (DispositionCustomField customField in dispositionCustomFields) {
      if(customField.options!.displayFor!.contains(int.parse(_selectedDisposition!.id!)) || 
        customField.options!.requireFor!.contains(int.parse(_selectedDisposition!.id!))){
        if(customField.type == DispositionCustomFieldTypes.Text || 
            customField.type == DispositionCustomFieldTypes.Textarea){
              Widget field = TextFormField(
                validator:(value) {
                  if ((value == null || value.isEmpty) &&  
                  customField.options!.requireFor!.contains(int.parse(_selectedDisposition!.id!))) {
                    return 'This field is required';
                  }
                  return null;
                },
                initialValue: _fieldValues![customField.id.toString()],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18
                ),
                minLines: customField.type ==  DispositionCustomFieldTypes.Textarea 
                  ? 7
                  : null,
                maxLines: customField.type ==  DispositionCustomFieldTypes.Textarea
                  ? 10
                  : null,
                decoration: InputDecoration(
                  errorStyle: TextStyle(fontWeight: FontWeight.w500, color: Colors.red.shade800),
                  alignLabelWithHint: true,
                  labelText:  customField.options!.requireFor!.contains(int.parse(_selectedDisposition!.id!)) 
                    ? "* ${customField.label}"
                    : customField.label,
                  labelStyle: TextStyle(
                    color: char,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ash.withOpacity(0.5)
                    )
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: ash.withOpacity(0.5)
                    )
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _fieldValues![customField.id.toString()] = value; 
                    _softphone!.setCallDispositionData(
                      callId: _call!.id, 
                      name: "fieldValues",
                      fieldValues: _fieldValues
                    );
                  });
                },
              );
            customFields.add(field);
        }
        if(customField.type == DispositionCustomFieldTypes.Dropdown){
          Widget dropdownButton = ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: char,
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              minimumSize: Size(double.infinity, 50)
            ),
            onPressed: ()=>_showCustomDropdownOptions(customField.options!.dropdownChoices, customField),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fieldValues![customField.id.toString()] ?? customField.label!,
                  style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700)
                ),
                Icon(Icons.expand_more, color: ash,size: 30,)
              ],   
            ),
          );
          customFields.add(dropdownButton);
        }
      }
    }
    return customFields;
  }

  void _showCustomDropdownOptions(List<String>? options, DispositionCustomField field){
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (contact) => PopupMenu(
        label: field.label,
        bottomChild: Container(
          height: MediaQuery.of(context).size.height / 2,
          child: options!.isNotEmpty 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if(options.isNotEmpty)
                    LimitedBox(
                      maxHeight: (MediaQuery.of(context).size.height / 2) - 50,
                      child: ListView.separated(
                        padding: EdgeInsets.only(left: 4),
                        itemCount: options.length,
                        separatorBuilder: (context, index) => Container(
                          padding: EdgeInsets.zero,
                          height: 1, 
                          width: double.infinity, 
                          color: halfSmoke
                        ),
                        itemBuilder: (BuildContext context,int index) {
                          return TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 0,vertical: 10),
                              alignment: Alignment.centerLeft,
                            ),
                            onPressed: () => {
                              setState(() {
                                _fieldValues![field.id.toString()] =  options[index];
                                _softphone!.setCallDispositionData(
                                  callId: _call!.id, 
                                  name: "fieldValues",
                                  fieldValues: _fieldValues
                                );
                                Navigator.of(context).pop();
                              },)
                            },
                            child: Text(
                              options[index],
                              textAlign: TextAlign.start,
                              style: TextStyle(
                                color: offWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w600
                              ),
                            ),
                          );
                        },
                      ),
                    )
                ],
              )
            : Center(child: Text("No Options Found", style: TextStyle(color: ash),),) 
        )
      )
    );
  }

  void _setDisposition(){
    SetDispositionPayload payload = SetDispositionPayload(
      phoneNumber: _phoneNumber, 
      fieldValues: _fieldValues, 
      notes: _notes
    );
    
    if(_selectedCallType != null){
      payload.callType = _selectedCallType;
    }

    if(_selectedDisposition != null){
      payload.dispositionId = _selectedDisposition!.id;
    }
    _fusionConnection!.apiV2Call(
      "post", 
      "/calls/${_call!.id}/setDisposition",
      payload.toJson()
    );
    _softphone!.endedCalls.removeWhere((call) => call.id == _call!.id);
    _onDone();
  }

  @override
  Widget build(BuildContext context) {
    String? callerName       = _softphone!.getCallerName(_call);
    String? companyName      = _softphone!.getCallerCompany(_call);
    String _linePrefix      = _softphone!.linePrefix;
    ImageProvider callerPic = _softphone!.getCallerPic(_call, callerName: callerName);

    return ListView(
      children: [
        if(!_fromCallView)
          Padding(
            padding: const EdgeInsets.only(top:32),
            child: Wrap(
              direction: Axis.horizontal,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left:16.0),
                  child: CircleAvatar(
                    backgroundImage: callerPic,
                    minRadius: 30,
                    maxRadius: 40,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if(_linePrefix.isNotEmpty) 
                      Text(_linePrefix,
                      style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: translucentWhite(0.67))),  
                    Text(
                      callerName == "Unknown" 
                        ? _phoneNumber!.formatPhone() 
                        : callerName!.toTitleCase(),
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.w700),),
                    Text(companyName!.capitalize(),
                      style:  TextStyle(
                      fontSize: 18,
                      height: 1.4,
                      color: translucentWhite(0.67),
                      fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              ],
            ),
          ),
        Container(
          margin: EdgeInsets.only(top: 30),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              key: _formKey,
              child: Wrap(
                runSpacing: 16,
                children: [
                  Wrap(
                    children: [
                      Container(
                        margin: EdgeInsets.only(bottom: 5),
                        decoration: BoxDecoration(
                          border: _showError 
                            ? Border.all(color: Colors.red.shade800, width: 1.5)
                            : null,
                          borderRadius: BorderRadius.circular(4)
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: char,
                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            minimumSize: Size(double.infinity, 50)
                          ),
                          onPressed: _openSelectDispo,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_selectedDisposition?.label ?? "Select a disposition",
                                style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.w700)
                              ),
                              Icon(Icons.expand_more, color: ash,size: 30,)
                            ],   
                          ),
                        ),
                      ),
                      if(_showError)
                        Padding(
                          padding: const EdgeInsets.only(left:12.0),
                          child: Text("Please select a disposition", 
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.w500, color: Colors.red.shade800,
                              height: 1.5
                            ),),
                        )
                    ]
                  ),
                  if(_callTypeEnabled)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: char,
                        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        minimumSize: Size(double.infinity, 50)
                      ),
                      onPressed: _openCallType,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedCallType?.label ?? "Select call type",
                            style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)
                          ),
                          Icon(Icons.expand_more, color: ash,size: 30,)
                        ],   
                      ),
                    ),
                  TextFormField(
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'This field is required';
                      }
                      return null;
                    },
                    style: TextStyle(
                      color: Colors.white,
                    ),
                    initialValue: _notes,
                    onChanged: (value) => {
                      _softphone!.setCallDispositionData(
                        callId: _call!.id, 
                        name: "dispositionNotes",
                        dispositionNotes: value
                      )
                    },
                    minLines: 7,
                    maxLines: 10,
                    decoration: InputDecoration(
                      errorStyle: TextStyle(fontWeight: FontWeight.w500, color: Colors.red.shade800),
                      alignLabelWithHint: true,
                      labelText: "Call notes",
                      labelStyle: TextStyle(
                        color: char
                      ),
                      border: OutlineInputBorder(
                        borderRadius:BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: ash.withOpacity(0.5)
                        )
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: ash.withOpacity(0.5)
                        )
                      ),
                    ),
                  ),
                  ...renderCustomFields(),
                  Container(
                    margin: EdgeInsets.only(top: 10),
                    child: Center(
                      child: Column(
                        verticalDirection: VerticalDirection.down,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              disabledBackgroundColor: char,
                              backgroundColor: char,
                              shape: CircleBorder(),
                              padding: EdgeInsets.all(10),
                            ),
                            onPressed: (){
                              if(_fromCallView){
                                _onDone();
                              } else{
                                if(_selectedDisposition == null && _dispositionOptions().isNotEmpty){
                                  setState(() {
                                    _showError = true;
                                  });
                                }
                                if (_formKey.currentState!.validate() && _selectedDisposition != null) {
                                  _setDisposition();
                                }
                              }
                            } , 
                            child: Icon(
                              _fromCallView 
                                ? Icons.close
                                : Icons.done,
                              color: Colors.white,
                              size: 34,
                            )
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(_fromCallView ? "CLOSE":"DONE", style: TextStyle(
                              fontSize: 14,
                              color: Colors.white)
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      ]
    );
  }
}