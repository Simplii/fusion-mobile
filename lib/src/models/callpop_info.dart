import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';

import '../backend/fusion_connection.dart';
import 'contact.dart';
import 'crm_contact.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';

class CallpopInfo extends FusionModel {
  String phoneNumber = "";
  List<CrmContact> crmContacts = [];
  List<Contact> contacts = [];
  List<dynamic> dispositionGroups = [];
  String _id = 'phoneNumber';

  CallpopInfo(Map<String, dynamic> map) {
    this.phoneNumber = map['phone_number'];
    this.contacts = map['contacts'];
    this.dispositionGroups = map['dispositions'];
    var added = {};
    this.contacts!.forEach((contact) {
      List<String?> emails = [];
      contact.emails!.forEach((email) {
        if(email['email'].runtimeType == String){
          emails.add(email['email']);
        }
      });
      contact.externalReferences!.forEach((extRef) {
        if (extRef['externalId'] != null) {
          var key = extRef['externalId'] + ':' + extRef['network'];
          if (!added.containsKey(key)) {
            added[key] = true;
            this.crmContacts.add(CrmContact(
                {
                  "crm": extRef['network'],
                  "emails": emails,
                  "icon": extRef['icon'],
                  "id": extRef['externalId'],
                  "nid": extRef['externalId'],
                  "label": extRef['name'] != null ? extRef['name'] : contact
                      .name,
                  "name": extRef['name'] != null ? extRef['name'] : contact
                      .name,
                  "module": extRef['module'],
                  "url": extRef['url'],
                  "phone_number": map['phone_number'],
                  "company": contact.company
                }
            ));
          }
        }
      });
    });
  }

  String? getId() => this.phoneNumber;

  String? getCompany({String? defaul}) {
    for (Contact c in contacts!) {
      if (c.company!.trim() != "") {
        return c.company;
      }
    }
    for (CrmContact c in crmContacts) {
      if (c.company!.trim() != '') {
        return c.company;
      }
    }
    return defaul != null ? defaul : "";
  }


  String getName({String? defaul}) {
    for (Contact c in contacts) {
      if (c.name != null && c.name!.trim() != "") {
        return c.name!;
      }
    }
    for (CrmContact c in crmContacts) {
      if (c.name != null && c.name!.trim() != '') {
        return c.name!;
      }
    }
    return defaul ?? "";
  }
}

class CallpopInfoStore extends FusionStore<CallpopInfo> {
  Map<String, CallpopInfo> _records = {};
  String _id_field = 'phone_number';

  CallpopInfoStore(FusionConnection _fusionConnection)
      : super(_fusionConnection);

  lookupPhone(String? phoneNumber, Function(CallpopInfo? callpopInfo) callback) {
    if (hasRecord(phoneNumber)) {
      return getRecord(phoneNumber, callback);
    }

    String? extOrPN = phoneNumber!.length <= 6 ? phoneNumber + "@" + fusionConnection.getDomain(): phoneNumber;

    fusionConnection.apiV2Call(
        "get",
        "/calls/callpopInfo",
        {'phoneNumber': extOrPN,
          'dialerGroupId': -1,
          'origination': super.fusionConnection.getUid(),
          'destination': phoneNumber},

        callback: (Map<String, dynamic> data) {
          List<Contact> contacts = [];

          if (data['contacts'] != null)
            for (Map<String, dynamic> obj in data['contacts']) {
              contacts.add(Contact.fromV2(obj));
            }

          CallpopInfo info = CallpopInfo({
            'phone_number': phoneNumber,
            'crm_contacts': [],
            'contacts': contacts,
            'dispositions': data['dispositionGroups']
          });

          storeRecord(info);
          callback(info);
        }
    );
  }
}
