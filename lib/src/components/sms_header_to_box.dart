import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';

import '../models/contact.dart';
import '../styles.dart';

class SendToBox extends StatefulWidget {
  final List<dynamic> sendToItems;
  final TextEditingController? searchTextController;
  final Function? search;
  final Function(int) deleteChip;
  final Function(dynamic) addChip;
  final int? chipsCount;
  final String? selectedDepartmentId;
  const SendToBox({
      required this.sendToItems, 
      required this.addChip,
      this.searchTextController, 
      this.search,
      required this.deleteChip, 
      this.chipsCount,
      required this.selectedDepartmentId,
      Key? key
    }) : super(key: key);

  @override
  State<SendToBox> createState() => _SendToBoxState();
}

class _SendToBoxState extends State<SendToBox> {
  List<dynamic> get contacts => widget.sendToItems;
  TextEditingController? get _searchTextController => widget.searchTextController;
  Function? get _search => widget.search;
  Function(int) get _deleteChip  => widget.deleteChip;
  Function(dynamic) get _addChip => widget.addChip;
  int? get chipsCount => widget.chipsCount;
  String? get _selectedDepartmentId => widget.selectedDepartmentId;
  
  
  ImageProvider _chipAvatar (int index){
    Contact contact = contacts.elementAt(index);
    if(contact.pictures!.length > 0){
      return NetworkImage(contact.pictures.last['url']);
    } else if (contact.profileImage != null){
      return MemoryImage(contact.profileImage!);
    } else {
      return NetworkImage(avatarUrl(contact.firstName!.toUpperCase(), contact.lastName));
    }
  }

  Text _chipLabel (int index){
    if(contacts.elementAt(index) is Contact){
      Contact contact = contacts.elementAt(index);
      String phoneType = (contact.phoneNumbers![0]['type'] != null  
        && contact.phoneNumbers![0]['type'] != "Mobile" )
          ? " - "+contact.phoneNumbers![0]['type']
          : '';
      String label = "${contact.name!.toTitleCase().toTitleCase()}${phoneType}";
      return Text(label);
    } else {
      return Text(contacts.elementAt(index).toString().formatPhone());
    }
  }

  @override
  Widget build(BuildContext context) {
    RegExp pattern = RegExp(r'(\d{3,4})@[a-zA-Z]*');
    bool addButtonDisabled = (chipsCount == 10 || 
      (_searchTextController!.value.text != '' && 
        _selectedDepartmentId == DepartmentIds.FusionChats && 
        !pattern.hasMatch(_searchTextController!.value.text)) || 
      _searchTextController!.value.text == ''
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          constraints: BoxConstraints(
            maxHeight: 80,
            minWidth: MediaQuery.of(context).size.width
          ),
          child: RawScrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              reverse: true,   
              child: Wrap(
                runSpacing: -10,
                spacing:5,
                children: List<Widget>.generate(chipsCount!, (index){
                  return InputChip(
                    labelPadding: EdgeInsets.only(left: 3,right: 1),
                    backgroundColor: ash,
                    avatar: contacts.elementAt(index) is Contact 
                      ? CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: _chipAvatar(index))
                            ),)
                        )
                      : null,
                    label: _chipLabel(index),
                    labelStyle: TextStyle(color: Colors.black,fontSize: 12.0),
                    onDeleted: ()=> _deleteChip(index),
                    elevation: 1,
                    deleteIcon: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: translucentSmoke
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(Icons.clear,color: coal, size: 15),
                      )));
                })
              ),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width - 58,
              ),
              margin: EdgeInsets.only(top: 0,right: 5),
              child: TextField(
                  controller: _searchTextController,
                  onChanged: _search as void Function(String)?,
                  decoration: InputDecoration(
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                          color: Color.fromARGB(255, 153, 148, 149),
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                      hintText: _selectedDepartmentId == DepartmentIds.FusionChats 
                        ? "Enter extension number"
                        : "Enter a name or phone number"),
                  style: TextStyle(
                      color: coal,
                      fontSize: 18,
                      fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: addButtonDisabled 
                  ? null 
                  : ()=> _addChip(null),
                child:Icon(
                  Icons.add_circle_outline, 
                  color: addButtonDisabled 
                    ? halfGray 
                    : crimsonLight
                ),
              )
            ]
        ),
      ]);
  }
}