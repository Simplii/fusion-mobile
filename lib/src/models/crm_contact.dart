import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';

import 'contact.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';

class CrmContact extends FusionModel {
  List<Map<String, String>> additions;
  Contact contact;
  String crm;
  List<String> emails;
  String icon;
  String id;
  String nid;
  String label;
  String module;
  String name;
  String url;
  String phone_number;
  String company;

  CrmContact.fromExpanded(Map<String, dynamic> contactObject) {
    if (contactObject['contact'] != null) {
      this.contact = Contact(contactObject['contact']);
    }

    this.crm = contactObject['network'];
    this.emails = [];
    if (contactObject['email'] != null && contactObject['email'].trim() != '') {
      this.emails.add(contactObject['email']);
    }
    if (contactObject['email2'] != null &&
        contactObject['email2'].trim() != '') {
      this.emails.add(contactObject['email2']);
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
        contactObject['phone_number'].trim() != '0' &&
        contactObject['phone_number'].trim() != '') {
      this.phone_number = contactObject['phone_number'];
    }
    if (contactObject['office_number'] != null &&
        contactObject['office_number'].trim() != '0' &&
        contactObject['office_number'].trim() != '') {
      this.phone_number = contactObject['office_number'];
    }
    if (contactObject['mobile_number'] != null &&
        contactObject['mobile_number'].trim() != '0' &&
        contactObject['mobile_number'].trim() != '') {
      this.phone_number = contactObject['mobile_number'];
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

  String getId() {
    return this.nid;
  }
}

class CrmContactsStore extends FusionStore<CrmContact> {
  Map<String, CrmContact> _records = {};
  String _id_field = 'nid';

  CrmContactsStore(FusionConnection fusionConnection) : super(fusionConnection);
}
