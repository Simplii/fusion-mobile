import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fusion_mobile_revamped/src/backend/softphone.dart';
import 'package:fusion_mobile_revamped/src/components/contact_circle.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_dropdown.dart';
import 'package:fusion_mobile_revamped/src/messages/sms_conversation_view.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../backend/fusion_connection.dart';
import '../components/popup_menu.dart';
import '../styles.dart';
import '../utils.dart';

class EditContactView extends StatefulWidget {
  final FusionConnection? _fusionConnection;
  final Function() _goBack;
  final Contact _contact;
  final Function? onCreate;

  EditContactView(
      this._fusionConnection, this._contact, this._goBack, this.onCreate,
      {Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _EditContactViewState();
}

class _EditContactViewState extends State<EditContactView> {
  FusionConnection? get _fusionConnection => widget._fusionConnection;

  Contact get _contact => widget._contact;
  Contact? _edited = null;
  Function? get _onCreate => widget.onCreate;
  bool _saving = false;
  Map<String, TextEditingController> textControllers = {};
  XFile? pickedImage = null;

  _textControllerFor(name, String? value) {
    if (textControllers.containsKey(name))
      return textControllers[name];
    else {
      textControllers[name] = TextEditingController(text: value);
      return textControllers[name];
    }
  }

  _startEditingIfNotStared() {
    if (_edited == null) {
      setState(() {
        _edited = Contact.copy(_contact);
      });
    }
  }

  _renderFieldEditor(String fieldName, String? fieldValue,
      String fieldPlaceholder, Function(String) onEdit) {
    return Row(children: [
      Expanded(
          child: _renderField(fieldName, fieldValue, fieldPlaceholder, onEdit))
    ]);
  }

  _renderField(String fieldName, String? fieldValue, String fieldPlaceholder,
      Function(String) onEdit,
      {EdgeInsets? margin}) {
    return _renderFieldWrapper(
        TextField(
          textCapitalization: TextCapitalization.sentences,
          onChanged: (String newValue) {
            _startEditingIfNotStared();
            onEdit(newValue);
          },
          controller: _textControllerFor(fieldName, fieldValue),
          style:
              TextStyle(color: coal, fontSize: 16, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
              border: InputBorder.none,
              hintStyle: TextStyle(
                  color: smoke, fontSize: 16, fontWeight: FontWeight.w400),
              hintText: fieldPlaceholder),
        ),
        margin);
  }

  _renderFieldWrapper(Widget child, EdgeInsets? margin) {
    return Container(
        margin: margin == null
            ? EdgeInsets.only(top: 12, bottom: 4, right: 0)
            : margin,
        padding: EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            color: ash),
        child: Container(
            padding: EdgeInsets.only(left: 12, right: 12),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                color: particle),
            child: child));
  }

  _renderDropDownField(String fieldName, String? fieldValue, String label,
      List<List<String>> options, Function(String) onEdit,
      {EdgeInsets? margin}) {
    return _renderFieldWrapper(
        Container(
            alignment: Alignment.center,
            padding: EdgeInsets.only(top: 16, bottom: 14),
            child: FusionDropdown(
                style: TextStyle(
                    color: coal, fontSize: 16, fontWeight: FontWeight.w700),
                label: label,
                selectedNumber: "",
                options: options,
                value: fieldValue != null ? fieldValue : "",
                onChange: (String value) {
                  _startEditingIfNotStared();
                  setState(() {
                    onEdit(value);
                  });
                })),
        margin);
  }

  _renderPhoneEditor(Map<String, dynamic> phone, int index) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
          child: _renderField("phone" + index.toString() + "phone",
              phone['number'], "Phone Number", (String newPhone) {
        _edited!.phoneNumbers![index]['number'] = newPhone;
      })),
      _renderDropDownField(
          "phone" + index.toString() + "type", phone['type'], "Phone Type", [
        ["Work", "Work"],
        ["Mobile", "Mobile"],
        ["Home", "Home"]
      ], (String newType) {
        _edited!.phoneNumbers![index]['type'] = newType;
      }, margin: EdgeInsets.only(left: 12, top: 12, bottom: 4)),
      GestureDetector(
          onTap: () {
            _startEditingIfNotStared();
            setState(() {
              _edited!.phoneNumbers!.removeAt(index);
            });
          },
          child: Container(
              decoration: clearBg(),
              padding: EdgeInsets.only(left: 12, right: 8),
              child: Image.asset("assets/icons/trashcan_red.png",
                  width: 18, height: 20)))
    ]);
  }

  _renderEmailEditor(Map<String, dynamic> email, int index) {
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            child: _renderField("email" + index.toString() + "email",
                email['email'], "Email Address", (String newEmail) {
          _edited!.emails![index]['email'] = newEmail;
        }))
      ]),
      Row(children: [
        _renderDropDownField(
            "email" + index.toString() + "type", email['type'], "Email Type", [
          ["Work", "Work"],
          ["Mobile", "Mobile"],
          ["Home", "Home"]
        ], (String newType) {
          _edited!.emails![index]['type'] = newType;
        }, margin: EdgeInsets.only(top: 12, bottom: 4)),
        GestureDetector(
            onTap: () {
              _startEditingIfNotStared();
              setState(() {
                _edited!.emails!.removeAt(index);
              });
            },
            child: Container(
                decoration: clearBg(),
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Image.asset("assets/icons/trashcan_red.png",
                    width: 18, height: 20)))
      ])
    ]);
  }

  _renderSocialEditor(Map<String, dynamic> social, int index) {
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
            child: _renderField(
                "social" + index.toString() + "social", social['value'], "Name",
                (String newSocialValue) {
          _edited!.socials![index]['value'] = newSocialValue;
        })),
        _renderDropDownField("social" + index.toString() + "type",
            social['social'], "Social Platform", [
          ["Linkedin", "Linkedin"],
          ["Facebook", "Facebook"],
          ["Twitter", "Twitter"],
          ["Instagram", "Instagram"],
          ["Website", "Website"],
        ], (String newType) {
          _edited!.socials![index]['type'] = newType;
        }, margin: EdgeInsets.only(top: 12, bottom: 4)),
        GestureDetector(
            onTap: () {
              _startEditingIfNotStared();
              setState(() {
                _edited!.socials!.removeAt(index);
              });
            },
            child: Container(
                decoration: clearBg(),
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Image.asset("assets/icons/trashcan_red.png",
                    width: 18, height: 20)))
      ])
    ]);
  }

  _addButton(String label, Function() onTap) {
    return GestureDetector(
        onTap: () {
          _startEditingIfNotStared();
          onTap();
        },
        child: Container(
            decoration: clearBg(),
            margin: EdgeInsets.only(top: 12),
            child: Row(children: [
              Container(
                  margin: EdgeInsets.only(right: 8),
                  alignment: Alignment.center,
                  child: Image.asset("assets/icons/plus_white.png",
                      width: 9.33, height: 9.33),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                      color: crimsonDark,
                      borderRadius: BorderRadius.all(Radius.circular(32)))),
              Text(label.toUpperCase(),
                  style: TextStyle(
                      color: crimsonDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w700))
            ])));
  }

  Contact? _editingContact() {
    return _edited == null ? _contact : _edited;
  }

  List<Widget> _fieldGroups() {
    Contact contact = _editingContact()!;
    List<Widget> groups = [];

    groups.add(_renderFieldGroup("user_filled_dark", [
      _renderFieldEditor("firstName", contact.firstName, "First Name",
          (String newVal) {
        _edited!.firstName = newVal;
      }),
      _renderFieldEditor("lastName", contact.lastName, "Last Name",
          (String newVal) {
        _edited!.lastName = newVal;
      })
    ]));

    groups.add(_renderFieldGroup("building_filled_dark", [
      _renderFieldEditor("company", contact.company, "Company",
          (String newVal) {
        _edited!.company = newVal;
      }),
      _renderFieldEditor("jobTitle", contact.jobTitle, "Job Title",
          (String newVal) {
        _edited!.jobTitle = newVal;
      })
    ]));

    List<Widget> phoneFields = [];
    int index = 0;
    for (Map<String, dynamic> phone in contact.phoneNumbers) {
      phoneFields.add(_renderPhoneEditor(phone, index));
      index++;
    }
    phoneFields.add(_addButton("ADD PHONE", () {
      setState(() {
        _edited!.phoneNumbers!.add({"number": "", "type": "Work"});
      });
    }));

    groups.add(_renderFieldGroup("phone_filled_dark", phoneFields));

    List<Widget> emailFields = [];
    index = 0;
    for (Map<String, dynamic> email in contact.emails!) {
      emailFields.add(_renderEmailEditor(email, index));
      index++;
    }
    emailFields.add(_addButton("ADD EMAIL", () {
      setState(() {
        _edited!.emails!.add({"email": "", "type": "Work"});
      });
    }));

    groups.add(_renderFieldGroup("mail_filled_dark", emailFields));

    if (contact.addresses == null || contact.addresses!.length == 0)
      contact.addresses = [{}];

    groups.add(_renderFieldGroup("geopointer_filled_dark", [
      _renderFieldEditor(
          "address1line1", contact.addresses![0]['address1'], "Address line 1",
          (String newVal) {
        contact.addresses![0]['address1'] = newVal;
      }),
      _renderFieldEditor(
          "address1line2", contact.addresses![0]['address2'], "Address line 2",
          (String newVal) {
        contact.addresses![0]['address2'] = newVal;
      }),
      _renderFieldEditor("address1city", contact.addresses![0]['city'], "City",
          (String newVal) {
        contact.addresses![0]['city'] = newVal;
      }),
      Row(children: [
        Expanded(
            child: _renderField(
                "address1state", contact.addresses![0]['state'], "State",
                (String newVal) {
          contact.addresses![0]['state'] = newVal;
        }, margin: EdgeInsets.only(top: 12, bottom: 4, right: 12))),
        Expanded(
            child: _renderField(
                "address1zip", contact.addresses![0]['zip'], "Zip code",
                (String newVal) {
          contact.addresses![0]['zip'] = newVal;
        }, margin: EdgeInsets.only(top: 12, bottom: 4))),
      ]),
      _renderFieldEditor(
          "address1country", contact.addresses![0]['country'], "Country",
          (String newVal) {
        contact.addresses![0]['country'] = newVal;
      }),
    ]));

    if (contact.socials == null || contact.socials!.length == 0)
      contact.socials = [];

    List<Widget> socials = [];
    index = 0;
    for (Map<String, dynamic> social in contact.socials) {
      socials.add(_renderSocialEditor(social, index));
      index++;
    }
    socials.add(_addButton("ADD SOCIAL", () {
      setState(() {
        _edited!.socials!.add({"value": "", "type": "Work"});
      });
    }));

    groups.add(_renderFieldGroup("web_filled_dark", socials));

    return groups;
  }

  _renderFieldGroup(String iconName, List<Widget> fields) {
    List<Widget> children = fields.toList();
    children.add(Container(margin: EdgeInsets.only(left: 0, right: 16)));

    return Container(
        margin: EdgeInsets.only(top: 24),
        padding: EdgeInsets.only(right: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              height: 20,
              width: 20,
              margin: EdgeInsets.only(left: 27, right: 16, top: 24),
              child: Image.asset("assets/icons/" + iconName + ".png",
                  height: 20, width: 20)),
          Expanded(child: Column(children: children))
        ]));
  }

  _header() {
    return Column(children: [
      Container(margin: EdgeInsets.all(8), child: Center(child: popupHandle())),
      Container(
          padding: EdgeInsets.only(top: 4, bottom: 16),
          child: Stack(children: [
            Center(
                child: Text(_onCreate != null ? "Add Contact" : "Edit Contact",
                    style: TextStyle(
                        color: coal,
                        fontSize: 16,
                        fontWeight: FontWeight.w700))),
            GestureDetector(
                onTap: widget._goBack,
                child: Container(
                    decoration: clearBg(),
                    padding:
                        EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 2),
                    child: Image.asset("assets/icons/arrow_left.png",
                        width: 14, height: 14)))
          ])),
    ]);
  }

  _saveButton() {
    return Container(
        padding: EdgeInsets.all(1),
        decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                  color: translucentBlack(0.06),
                  offset: Offset(0, 1),
                  blurRadius: 1.93),
              BoxShadow(
                  color: translucentBlack(0.1),
                  offset: Offset(0, 3.5),
                  blurRadius: 6.48)
            ],
            borderRadius: BorderRadius.all(Radius.circular(50)),
            color: crimsonLight,
            gradient: LinearGradient(
              colors: [lighten(crimsonLight, 80), darken(crimsonLight, 30)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )),
        child: Container(
            padding: EdgeInsets.only(top: 12, bottom: 14, left: 18, right: 22),
            decoration: BoxDecoration(
              color: crimsonLight,
              borderRadius: BorderRadius.all(Radius.circular(50)),
            ),
            child: Row(children: [
              _saving
                  ? Container(
                      margin: EdgeInsets.only(right: 8),
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white))
                  : Container(
                      child: Image.asset("assets/icons/check_white.png",
                          width: 16, height: 11),
                      margin: EdgeInsets.only(right: 8)),
              Text("SAVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ))
            ])));
  }

  _saveContact() {
    setState(() {
      _saving = true;
    });
    _edited!.name = _edited!.firstName! + " " + _edited!.lastName!;
    if (pickedImage != null) {
      _fusionConnection!.contacts.uploadProfilePic(
          "contact", pickedImage!, _edited!, (Contact updatedContact) {
        _fusionConnection!.contacts.save(updatedContact, () {
          setState(() {
            _contact!.copy(updatedContact);
            _saving = false;
            _edited = null;
          });
        });
      });
    } else {
      _fusionConnection!.contacts.save(_edited, () => {});
      _contact!.copy(_edited!);
      widget._goBack();
    }
  }

  _createContact() {
    setState(() {
      _saving = true;
    });
    if (pickedImage != null) {
      _fusionConnection!.contacts.createContact(_edited!, (Contact newContact) {
        _fusionConnection!.contacts.uploadProfilePic(
            "contact", pickedImage!, newContact, (Contact updatedContact) {
          _fusionConnection!.contacts.save(updatedContact, () {
            setState(() {
              _saving = false;
              _contact!.copy(newContact);
              _onCreate!();
              widget._goBack();
            });
          });
        });
      });
    } else {
      _fusionConnection!.contacts.createContact(_edited!, (Contact newContact) {
        _contact!.copy(newContact);
        _onCreate!();
        widget._goBack();
      });
    }
  }

  void _selectImage(String source) {
    final ImagePicker _picker = ImagePicker();
    Contact? contact = _editingContact();
    if (source == "camera") {
      _picker.pickImage(source: ImageSource.camera).then((XFile? image) {
        setState(() {
          if (image == null) return;
          setState(() {
            pickedImage = image;
            _edited = contact;
            Navigator.of(this.context).pop();
          });
        });
      });
    } else {
      _picker.pickImage(source: ImageSource.gallery).then((XFile? image) {
        if (image == null) return;
        setState(() {
          pickedImage = image;
          _edited = contact;
          Navigator.of(this.context).pop();
        });
      });
    }
  }

  _uploadPic() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => PopupMenu(
        label: "Source",
        bottomChild: Container(
          height: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => _selectImage("camera"),
                child: Container(
                  padding: EdgeInsets.only(bottom: 10, top: 14, left: 12),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: lightDivider, width: 1.0))),
                  child: Text(
                    'Camera',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _selectImage("photos"),
                child: Container(
                  padding: EdgeInsets.only(bottom: 10, top: 14, left: 12),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: lightDivider, width: 1.0))),
                  child: Text(
                    'Photos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? pictureUrl = _contact!.pictureUrl();
    print("MDBM ${_edited?.firstName} ${_edited?.lastName}");
    return Column(children: [
      _header(),
      Expanded(
          child: Stack(children: [
        Column(children: [
          Container(
              height: 250,
              decoration: BoxDecoration(
                  color: Colors.black,
                  image: DecorationImage(
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.6), BlendMode.dstATop),
                      image: pickedImage != null
                          ? FileImage(File(pickedImage!.path))
                          : (pictureUrl != null
                                  ? NetworkImage(pictureUrl)
                                  : AssetImage("assets/blank_avatar.png"))
                              as ImageProvider<Object>))),
          Expanded(
              child: Container(
                  decoration: BoxDecoration(color: Colors.white),
                  child: ListView(
                      padding: EdgeInsets.only(bottom: 72),
                      children: _fieldGroups())))
        ]),
        Positioned(
            height: 250,
            width: MediaQuery.of(context).size.width,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _uploadPic,
              child: Center(
                  child: Icon(
                Icons.local_see_outlined,
                color: Colors.white,
                size: 35,
              )),
            )),
        if ((_edited?.firstName != null && _edited!.firstName!.isNotEmpty) &&
            (_edited?.lastName != null && _edited!.lastName!.isNotEmpty))
          Container(
              alignment: Alignment.bottomCenter,
              padding: EdgeInsets.only(bottom: 32),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                GestureDetector(
                    onTap: _onCreate != null ? _createContact : _saveContact,
                    child: _saveButton())
              ]))
      ]))
    ]);
  }
}
