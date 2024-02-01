import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gravatar/flutter_gravatar.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';

import '../styles.dart';

class ContactCircle extends StatefulWidget {
  final List<Contact?>? _contacts;
  final List<CrmContact?>? _crmContacts;
  Coworker? _coworker;
  double _diameter = 60;
  double? _margin = null;
  bool? _isGroupSms;
  bool isBroadcastSms = false;

  ContactCircle(this._contacts, this._crmContacts, {Key? key})
      : super(key: key);
  ContactCircle.withCoworker(this._contacts, this._crmContacts, this._coworker,
      {Key? key})
      : super(key: key);

  ContactCircle.withCoworkerAndDiameter(
      this._contacts, this._crmContacts, this._coworker, this._diameter,
      {Key? key})
      : super(key: key);

  ContactCircle.withDiameter(this._contacts, this._crmContacts, this._diameter,
      {Key? key})
      : super(key: key);

  ContactCircle.withDiameterAndMargin(
      this._contacts, this._crmContacts, this._diameter, this._margin,
      {Key? key})
      : super(key: key);
  ContactCircle.forSMS(
    this._contacts,
    this._crmContacts,
    this._isGroupSms,
    this.isBroadcastSms, {
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ContactCircleState();
}

class _ContactCircleState extends State<ContactCircle> {
  List<Contact?>? get _contacts => widget._contacts;
  List<CrmContact?>? get _crmContacts => widget._crmContacts;
  Coworker? get _coworker => widget._coworker;
  double get _diameter => widget._diameter;
  double? get _margin => widget._margin;
  bool? get _isGroupSms => widget._isGroupSms;
  bool get _isBroadcastSms => widget.isBroadcastSms;

  _gravatarUrl(String email, String firstName, String lastName) {
    firstName = firstName.replaceAll(r"/[^a-zA-Z]/", '');
    lastName = lastName.replaceAll(r"/[^a-zA-Z]/", '');
    return Gravatar(email).imageUrl(
        size: 120,
        defaultImage: Uri.encodeComponent(avatarUrl(firstName, lastName)));
  }

  _firstName() {
    if (_contacts!.length > 0) {
      return _contacts![0]!.firstName;
    } else if (_crmContacts!.length > 0) {
      return _crmContacts![0]!.name!.split(" ")[0];
    } else {
      return "Unknown";
    }
  }

  _lastName() {
    if (_contacts!.length > 0) {
      return _contacts![0]!.lastName;
    } else if (_crmContacts!.length > 0) {
      return _crmContacts![0]!.name!.split(" ")[1];
    } else {
      return "Unknown";
    }
  }

  Widget _chatHeads(int idx, Contact c) {
    String _imageUrl = c.pictures.length > 0
        ? c.pictures.last['url']
        : avatarUrl(c.firstName, c.lastName);
    ImageProvider image = c.profileImage != null
        ? MemoryImage(c.profileImage!)
        : NetworkImage(_imageUrl) as ImageProvider;

    switch (idx) {
      case 0:
        return Positioned(
          left: 0,
          child: Container(
            height: 35,
            width: 35,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                image: DecorationImage(fit: BoxFit.cover, image: image)),
          ),
        );
        break;
      case 1:
        return Positioned(
          right: 0,
          top: _contacts!.length != 2 ? 2 : null,
          bottom: _contacts!.length == 2 ? 0 : null,
          child: Container(
            height: _contacts!.length == 2 ? 28 : 22,
            width: _contacts!.length == 2 ? 28 : 22,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                image: DecorationImage(fit: BoxFit.cover, image: image)),
          ),
        );
        break;
      case 2:
        return Positioned(
          bottom: 0,
          left: _contacts!.length == 4 ? 5 : null,
          right: _contacts!.length == 3 ? 0 : null,
          child: Container(
            height: _contacts!.length == 3 ? 28 : 22,
            width: _contacts!.length == 3 ? 28 : 22,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                image: DecorationImage(fit: BoxFit.cover, image: image)),
          ),
        );
        break;
      case 3:
        return _contacts!.length > 4
            ? Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                      // color: coal,
                      color: crimsonDarker,
                      borderRadius: BorderRadius.circular(50)),
                  child: Center(
                    child: Text(
                      "+${(_contacts!.length - 3).toString()}",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              )
            : Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      image: DecorationImage(fit: BoxFit.cover, image: image)),
                ),
              );
        break;
      default:
        return Container();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    String? imageUrl = null;
    ImageProvider? profileImage = null;
    Coworker? coworker = _coworker;
    List<Contact?>? groupAvatar =
        _contacts!.length > 4 ? _contacts!.sublist(0, 4) : _contacts;
    if (_contacts != null) {
      for (Contact? contact in _contacts!) {
        if (contact!.coworker != null && coworker == null) {
          coworker = contact.coworker;
        } else if (contact.pictures.length > 0 &&
            contact.profileImage == null) {
          imageUrl = contact.pictures.last['url'];
        } else if (contact.emails.isNotEmpty && contact.profileImage == null) {
          for (Map<String, dynamic> email in contact.emails) {
            try {
              imageUrl = _gravatarUrl(
                  email['email'], contact.firstName!, contact.lastName!);
            } catch (e) {}
          }
        } else if (contact.profileImage != null) {
          profileImage = MemoryImage(contact.profileImage!);
          imageUrl = null;
        }
      }
    }
    if (_crmContacts != null) {
      for (CrmContact? contact in _crmContacts!) {
        if (contact!.emails != null) {
          for (String? email in contact.emails!) {
            try {
              imageUrl = _gravatarUrl(
                email!,
                contact.name!.split(' ')[0],
                contact.name!.split(' ')[1],
              );
            } catch (e) {}
          }
        }
      }
    }

    String? presence = null;
    if (coworker != null) {
      imageUrl = coworker.url;
      presence = coworker.presence;
    }

    if (imageUrl == null &&
        profileImage == null &&
        (_contacts!.length > 0 || _crmContacts!.length > 0)) {
      imageUrl = avatarUrl(_firstName(), _lastName());
    }

    Widget contactImage = ClipRRect(
        borderRadius: BorderRadius.circular((_diameter - 4) / 2),
        child: Container(
          width: _diameter - 4,
          height: _diameter - 4,
          child: _isBroadcastSms
              ? Container(
                  color: Colors.black,
                  child: Center(
                    child: Image.asset("assets/icons/broadcast-message.png"),
                  ),
                )
              : imageUrl != null
                  ? CircleAvatar(
                      //backgroundImage here will be a fallback incase the image we're getting
                      //from imageUrl was deleted from the server
                      backgroundImage:
                          NetworkImage(avatarUrl(_firstName(), _lastName())),
                      foregroundImage: profileImage != null
                          ? profileImage
                          : NetworkImage(imageUrl),
                    )
                  : CircleAvatar(
                      backgroundImage: profileImage != null
                          ? profileImage
                          : AssetImage("assets/blank_avatar.png"),
                    ),
        ));

    Color borderColor = Colors.transparent;
    if (presence == "open")
      borderColor = Color.fromARGB(255, 0, 204, 136);
    else if (presence == 'inactive')
      borderColor = smoke;
    else if (presence == 'ringing' ||
        presence == 'alerting' ||
        presence == 'progressing')
      borderColor = informationBlue;
    else if (presence == 'inuse' || presence == 'held')
      borderColor = crimsonLight;
    if (_isGroupSms != null && _isGroupSms! && !_isBroadcastSms)
      return Container(
          margin: EdgeInsets.only(right: _diameter / 3),
          width: _diameter,
          height: _diameter,
          decoration: BoxDecoration(
              color: particle, borderRadius: BorderRadius.circular(100)),
          child: Stack(
              children: groupAvatar!.asMap().entries.map((e) {
            int idx = e.key;
            Contact val = e.value!;
            return _chatHeads(idx, val);
          }).toList()));

    return Container(
        margin: EdgeInsets.only(
            right: this._margin != null ? this._margin! : _diameter / 3),
        decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.all(Radius.circular(_diameter / 2))),
        width: _diameter,
        height: _diameter,
        child: Container(
            decoration: BoxDecoration(
                border: Border.all(color: Colors.transparent, width: 2),
                borderRadius:
                    BorderRadius.all(Radius.circular((_diameter - 4) / 2))),
            width: _diameter - 4,
            height: _diameter - 4,
            child: contactImage));
  }
}
