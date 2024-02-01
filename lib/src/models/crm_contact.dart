import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'dart:convert' as convert;

import 'contact.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';

class CrmContact extends FusionModel {
  List<Map<String, String>>? additions;
  Contact? contact;
  String? crm;
  List<String?>? emails;
  String? icon;
  String? id;
  String? nid;
  String? label;
  String? module;
  String? name;
  String? url;
  String? phone_number;
  String? company = "";

  String serialize() {
    return convert.jsonEncode({
    'additions': this.additions,
      // skipping to avoid loops
    //'contact': this.contact != null ? this.contact.serialize() : null,
    'crm': this.crm,
    'emails': this.emails,
    'icon': this.icon,
    'id': this.id,
    'nid': this.nid,
    'label': this.label,
    'module': this.module,
    'name': this.name,
    'url': this.url,
    'phone_number': this.phone_number,
    'company': this.company,
    });
  }

  CrmContact.unserialize(String data) {
    Map<String, dynamic> obj = convert.jsonDecode(data);
    if(obj['additions'] != null)
      this.additions = obj['additions'].cast<Map<String, String>>();
    if (obj['contact'] != null)
      this.contact = Contact.unserialize(obj['contact']);
    this.crm = obj['crm'];
    this.emails = obj['emails'].cast<String>();
    this.icon = obj['icon'];
    this.id = obj['id'];
    this.nid = obj['nid'];
    this.label = obj['label'];
    this.module = obj['module'];
    this.name = obj['name'];
    this.url = obj['url'];
    this.phone_number = obj['phone_number'];
    this.company = obj['company'];

  }

  toContact() {
    Contact c = Contact({
      'addresses': [],
      'company': "",
      'contacts': [],
      'deleted': false,
      'domain': "",
      'emails': [],
      'first_contact_diate': '',
      'first_name': this.name!.split(' ')[0],
      'last_name': this.name!.split(' ')[1],
      'groups': [],
      'id': this.id,
      'job_title': '',
      'lead_creation_date': '',
      'name': this.name,
      'owner': '',
      'parent_id': '',
      'phone_numbers': [{'number': this.phone_number, 'type': ''}],
      'pictures': [],
      'socials': [],
      'type': '',
      'updated_at': {'date': '', 'timezone': '', 'timezone_type': 1},
      'created_at': {'date': '', 'timezone': '', 'timezone_type': 1},
      'crm_url': '',
      'crm_name': this.crm,
      'crm_id': this.id}
    );
    return c;
  }
  CrmContact.fromExpanded(Map<String, dynamic> contactObject) {
    if (contactObject['contact'] != null) {
      this.contact = Contact(contactObject['contact']);
    }

    this.crm = contactObject['network'];
    this.emails = [];
    if (contactObject['email'] != null && contactObject['email'].trim() != '') {
      this.emails!.add(contactObject['email']);
    }

    if (contactObject['email2'] != null &&
        contactObject['email2'].trim() != '') {
      this.emails!.add(contactObject['email2']);
    }

    if (contactObject['network'] == null) {
      contactObject['network'] = "Fusion";
    }

    this.id = contactObject['network_id'].toString();
    this.nid = contactObject['network'].toString() +
        ":" +
        contactObject['network_id'].toString();
    this.label = contactObject['name'];
    this.module = contactObject['module'];
    this.name = contactObject['name'];
    this.url = contactObject['url'];
    if (contactObject['phone_number'] != null &&
        contactObject['phone_number'].toString().trim() != '0' &&
        contactObject['phone_number'].toString().trim() != '') {
      this.phone_number = contactObject['phone_number'].toString();
    }
    if (contactObject['office_number'] != null &&
        contactObject['office_number'].toString().trim() != '0' &&
        contactObject['office_number'].toString().trim() != '') {
      this.phone_number = contactObject['office_number'].toString();
    }
    if (contactObject['office_phone'] != null &&
        contactObject['office_phone'] != 0 &&
        contactObject['office_phone'].toString().trim() != '') {
      this.phone_number = contactObject['office_phone'].toString();
    }
    if (contactObject['mobile_number'] != null &&
        contactObject['mobile_number'].toString().trim() != '0' &&
        contactObject['mobile_number'].toString().trim() != '') {
      this.phone_number = contactObject['mobile_number'].toString();
    }
    if (contactObject['mobile_phone'] != null &&
        contactObject['mobile_phone'] != 0 &&
        contactObject['mobile_phone'].toString().trim() != '') {
      this.phone_number = contactObject['mobile_phone'].toString();
    }
    if (contactObject['home_phone'] != null &&
        contactObject['home_phone'] != 0 &&
        contactObject['home_phone'].toString().trim() != '') {
      this.phone_number = contactObject['home_phone'].toString();
    }
    this.company = contactObject['company'];
  }

  CrmContact(Map<String, dynamic> contactObject) {
    if (contactObject['additions'] != null) {
      this.additions = contactObject['additions'].cast<Map<String, String>>();
    } else {
      this.additions = [];
    }

    if (contactObject['contact'] != null) {
      this.contact = Contact(contactObject['contact']);
    }

    this.crm = contactObject['crm'];
    this.emails = contactObject['emails'].cast<String>();
    this.icon = contactObject['icon'];
    this.id = contactObject['id'].toString();
    this.nid = contactObject['crm'] + ":" + contactObject['id'].toString();
    this.label = contactObject['label'];
    this.module = contactObject['module'];
    this.name = contactObject['name'];
    this.url = contactObject['url'];
    this.phone_number = contactObject['phone_number'];
    this.company = contactObject['company'];
  }

  String? getId() {
    return this.nid;
  }

   List<String?> numbersAsStrings() {
    List<String?> numbers = [];
    if (phone_number != null && phone_number!.trim().length > 2)
        numbers.add(phone_number);
    if (phone_number != null && phone_number!.trim().length > 2)
        numbers.add(phone_number);
    if (phone_number != null && phone_number!.trim().length > 2)
        numbers.add(phone_number);

    return numbers;
  }

  String? firstNumber() {
    List<String?> numbers = numbersAsStrings();
    if (numbers.length > 0)
      return numbers[0];
    else
      return null;
  }
}

class CrmContactsStore extends FusionStore<CrmContact> {
  Map<String, CrmContact> _records = {};
  String _id_field = 'nid';

  CrmContactsStore(FusionConnection fusionConnection) : super(fusionConnection);
}
