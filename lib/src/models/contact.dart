import 'dart:io';
import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/call_history.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/phone_contact.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert' as convert;

import 'carbon_date.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:http_parser/http_parser.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';

class ContactCrmReference {
  String? crmName;
  String? module;
  String? contactName;
  String? url;
  String? crmContactId;
  String? icon;

  ContactCrmReference(
      {this.crmName,
      this.module,
      this.contactName,
      this.url,
      this.crmContactId,
      this.icon});
}

class Contact extends FusionModel {
  List<dynamic>? addresses;
  String? company;
  List<dynamic>? contacts;
  CarbonDate? createdAt;
  bool? deleted;
  String? domain;
  List<dynamic> emails = [];
  String? firstContactDate;
  Coworker? coworker;
  String? firstName = "";
  List<String>? groups;
  String id = "";
  String? jobTitle;
  String? lastName = "";
  String? leadCreationDate;
  String? name;
  String? owner;
  String? parentId;
  List<dynamic> phoneNumbers = [];
  List<dynamic> pictures = [];
  List<dynamic> socials = [];
  List<dynamic> externalReferences = [];
  Map<String, dynamic>? lastCommunication;
  String? type;
  String? uid;
  CarbonDate? updatedAt;
  String? crmUrl;
  String? crmName;
  String? crmId;
  int? unread = 0;
  List<dynamic>? fieldValues = [];
  Uint8List? profileImage;
  @override
  String? getId() => this.id;

  List<String?> numbersAsStrings() {
    List<String?> numbers = [];
    for (Map<String, dynamic> number in phoneNumbers) {
      if (number['number'] != null && number['number'].trim().length > 2) {
        numbers.add(number['number']);
      }
    }
    return numbers;
  }

  String? firstNumber() {
    List<String?> numbers = numbersAsStrings();
    if (numbers.length > 0)
      return numbers[0];
    else
      return null;
  }

  String fullName() {
    String name = (firstName! + " " + lastName!).trim();
    return name == "" ? "Unknown" : name;
  }

  List<ContactCrmReference> crms() {
    List<ContactCrmReference> matches = [];

    if (contacts != null) {
      for (Map<String, dynamic> obj in contacts!) {
        matches.add(ContactCrmReference(
            url: obj['url'],
            crmContactId: obj['network_id'].toString(),
            contactName: obj['name'],
            crmName: obj['network'],
            module: obj['module'],
            icon: obj['icon']));
      }
    }

    return matches;
  }

  String? pictureUrl() {
    if (pictures.isNotEmpty) {
      return pictures.last['url'];
    }
    if (emails.isNotEmpty) {
      for (Map<String, dynamic> email in emails) {
        if (email['email'] != null && email['email'].trim() != '') {}
      }
    }
    return null;
  }

  searchString() {
    List<String?> list = [company, firstName, lastName];
    for (Map<String, dynamic> number in phoneNumbers) {
      list.add(number['number'].toString());
    }
    for (Map<String, dynamic> email in emails) {
      list.add(email['email'].toString());
    }
    return list.join(' ');
  }

  Contact(Map<String, dynamic> contactObject) {
    Map<String, dynamic>? createdAtDateObj;
    if (contactObject['created_at'] != null)
      createdAtDateObj = checkDateObj(contactObject['created_at'])!;
    Map<String, dynamic>? updatedAtDateObj;
    if (contactObject['updated_at'] != null)
      updatedAtDateObj = checkDateObj(contactObject['updated_at'])!;
    this.addresses = contactObject['addresses'];
    this.company = contactObject['company'];
    this.contacts = contactObject['contacts'];
    this.createdAt =
        createdAtDateObj != null ? CarbonDate(createdAtDateObj) : null;
    this.deleted = contactObject['deleted'];
    this.domain = contactObject['domain'];
    this.emails = contactObject['emails'];
    this.firstContactDate = contactObject['first_contact_date'];
    this.firstName = contactObject['first_name'];
    this.groups = contactObject['groups'].cast<String>();
    this.id = contactObject['id'].toString();
    this.jobTitle = contactObject['job_title'];
    this.lastName = contactObject['last_name'];
    this.leadCreationDate = contactObject['lead_creation_date'];
    this.name = contactObject['name'];
    this.owner = contactObject['owner'];
    this.parentId = contactObject['parent_id'].toString();
    this.phoneNumbers = [];
    for (var number in contactObject['phone_numbers']) {
      this.phoneNumbers.add({
        "number": number['number'].toString(),
        "sms_capable": number['sms_capable'],
        "type": number['type']
      });
    }
    this.pictures = contactObject['pictures'];
    this.socials = contactObject['socials'];
    this.type = contactObject['type'];
    if (contactObject['uid'].runtimeType == String) {
      this.uid = contactObject['uid'];
    }
    this.updatedAt =
        updatedAtDateObj != null ? CarbonDate(updatedAtDateObj) : null;
    this.crmUrl = contactObject['crm_url'];
    this.crmName = contactObject['crm_name'];
    this.crmId = contactObject['crm_id'].runtimeType == int
        ? contactObject['crm_id'].toString()
        : contactObject['crm_id'];
    this.profileImage = contactObject["profileImage"] ?? null;
  }

  Contact.fake(dynamic number, {String firstName = "", String lastName = ""}) {
    String date = DateTime.now().toString();
    this.addresses = [];
    this.company = '';
    this.externalReferences = [];
    this.createdAt = CarbonDate.fromDate(date);
    this.deleted = false;
    this.emails = [];
    this.firstName = firstName;
    this.groups = [];
    this.id = '';
    this.jobTitle = '';
    this.lastName = lastName;
    this.name = firstName.isNotEmpty 
      ? "$firstName $lastName" 
      : number.toString().formatPhone();
    this.owner = '';
    this.phoneNumbers = [
      {"number": number, "smsCapable": true, "type": 'Mobile'}
    ];
    this.pictures = [];
    this.socials = [];
    this.type = '';
    this.updatedAt = CarbonDate.fromDate(date);
  }

  Contact.fromV2(Map<String, dynamic> contactObject) {
    addresses = [];
    var address;
    if (contactObject['addresses'] != null) {
      for (address in contactObject['addresses']) {
        address['zip-2'] = address['zipPart2'];
        addresses!.add([address]);
      }
    }
    this.addresses = contactObject['addresses'];
    this.company = contactObject['company'];
    this.externalReferences = contactObject['externalReferences'] ?? [];
    this.createdAt = CarbonDate.fromDate(contactObject['createdAt']);
    this.deleted = false;
    this.emails = contactObject['emails'];
    this.firstName = contactObject['firstName'];
    this.groups = contactObject['tags'] != null
        ? contactObject['tags'].cast<String>()
        : [];
    this.id = contactObject['id'];
    this.jobTitle = contactObject['jobTitle'];
    this.lastName = contactObject['lastName'];
    this.name = "${contactObject['firstName']} ${contactObject['lastName']}";
    this.owner = contactObject['owner'];
    this.phoneNumbers = [];
    if (contactObject['phoneNumbers'] != null) {
      for (var number in contactObject['phoneNumbers']) {
        this.phoneNumbers.add({
          "number": number['number'].toString(),
          "smsCapable": number['smsCapable'],
          "type": number['type']
        });
      }
    }
    this.pictures = contactObject['pictures'];
    this.socials = contactObject['socials'];
    this.type = contactObject['type'];
    this.updatedAt = CarbonDate.fromDate(contactObject['updatedAt']);

    if (this.externalReferences.isNotEmpty) {
      this.crmUrl = externalReferences[0]['url'];
      this.crmName = externalReferences[0]['network'];
      this.crmId = externalReferences[0]['externalId'];
    }
    this.fieldValues = contactObject['fieldValues'] != null
        ? contactObject['fieldValues']
        : [];
  }

  Map<String, dynamic> serverPayload() {
    return {
      "addresses": addresses,
      "company": company,
      "contacts": contacts,
      "emails": emails,
      "first_name": firstName,
      "groups": groups,
      "id": id,
      "job_title": jobTitle,
      "last_name": lastName,
      "name": name,
      "owner": owner,
      "phone_numbers": phoneNumbers,
      "pictures": pictures,
      "socials": socials,
      "type": type,
      "uid": uid
    };
  }

  Map<String, dynamic> serverPayloadV2() {
    return {
      "addresses": addresses,
      "company": company,
      "emails": emails,
      "externalReferences": [],
      "fieldValues": fieldValues!.isNotEmpty
          ? fieldValues
          : [
              {"fieldName": "first_name", "value": firstName},
              {"fieldName": "last_name", "value": lastName},
              {"fieldName": "company", "value": company},
              {"fieldName": "job_title", "value": jobTitle},
              {"fieldName": "owner", "value": owner},
              {"fieldName": "name", "value": "${firstName} ${lastName}"}
            ],
      "firstName": firstName,
      "jobTitle": jobTitle,
      "lastName": lastName,
      "owner": owner,
      "phoneNumbers": phoneNumbers,
      "pictures": pictures,
      "socials": socials,
      "tags": groups,
      "type": type != '' ? type : "Contact"
    };
  }

  serialize() {
    return convert.jsonEncode({
      'addresses': this.addresses,
      'company': this.company,
      'contacts': this.contacts,
      'createdAt': this.createdAt?.serialize(),
      'deleted': this.deleted,
      'domain': this.domain,
      'emails': this.emails,
      'firstContactDate': this.firstContactDate,
      'coworker': this.coworker?.serialize(),
      'firstName': this.firstName,
      'groups': this.groups,
      'id': this.id,
      'jobTitle': this.jobTitle,
      'lastName': this.lastName,
      'leadCreationDate': this.leadCreationDate,
      'name': this.name,
      'owner': this.owner,
      'parentId': this.parentId,
      'phoneNumbers': this.phoneNumbers,
      'pictures': this.pictures,
      'socials': this.socials,
      'lastCommunication': this.lastCommunication,
      'type': this.type,
      'uid': this.uid,
      'updatedAt': this.updatedAt?.serialize(),
      'crmUrl': this.crmUrl,
      'crmName': this.crmName,
      'crmId': this.crmId,
      'unread': this.unread,
      'profileImage': this.profileImage
    });
  }

  Contact.unserialize(String data) {
    Map<String, dynamic> obj = convert.jsonDecode(data);
    this.addresses = obj['addresses'];
    this.company = obj['company'];
    this.contacts = obj['contacts'];
    this.createdAt = obj['createdAt'] != null
        ? CarbonDate?.unserialize(obj['createdAt'])
        : CarbonDate.fromDate(DateTime.now().toLocal().toString());
    this.deleted = obj['deleted'];
    this.domain = obj['domain'];
    this.emails = obj['emails'];
    this.firstContactDate = obj['firstContactDate'];
    this.coworker = obj['coworker'] != '' && obj['coworker'] != null
        ? Coworker(convert.jsonDecode(obj['coworker']))
        : obj['coworker'];
    this.firstName = obj['firstName'];
    this.groups = obj['groups'].cast<String>();
    this.id = obj['id'];
    this.jobTitle = obj['jobTitle'];
    this.lastName = obj['lastName'];
    this.leadCreationDate = obj['leadCreationDate'];
    this.name = obj['name'];
    this.owner = obj['owner'];
    this.parentId = obj['parentId'];
    this.phoneNumbers = obj['phoneNumbers'].cast<Map<String, dynamic>>();
    this.pictures = obj['pictures'].cast<Map<String, dynamic>>();
    this.socials = obj['socials'].cast<Map<String, dynamic>>();
    this.lastCommunication = obj['lastCommunication'];
    this.type = obj['type'];
    this.uid = obj['uid'];
    this.updatedAt = obj['updatedAt'] != null
        ? CarbonDate?.unserialize(obj['updatedAt'])
        : CarbonDate.fromDate(DateTime.now().toLocal().toString());
    this.crmUrl = obj['crmUrl'];
    this.crmName = obj['crmName'];
    this.crmId = obj['crmId'];
    this.unread = obj['unread'];
    this.profileImage = getImageBinary(obj['profileImage']);
  }

  Contact.copy(Contact contact) {
    this.addresses = convert.jsonDecode(convert.jsonEncode(contact.socials));
    this.company = contact.company;
    this.contacts = contact.contacts;
    this.createdAt = contact.createdAt;
    this.deleted = contact.deleted;
    this.domain = contact.domain;
    this.emails = convert.jsonDecode(convert.jsonEncode(contact.emails));
    this.firstContactDate = contact.firstContactDate;
    this.coworker = contact.coworker;
    this.firstName = contact.firstName;
    this.groups = contact.groups;
    this.id = contact.id;
    this.jobTitle = contact.jobTitle;
    this.lastName = contact.lastName;
    this.leadCreationDate = contact.leadCreationDate;
    this.name = contact.name;
    this.owner = contact.owner;
    this.parentId = contact.parentId;
    this.phoneNumbers =
        convert.jsonDecode(convert.jsonEncode(contact.phoneNumbers));
    this.pictures = convert.jsonDecode(convert.jsonEncode(contact.pictures));
    this.socials = convert.jsonDecode(convert.jsonEncode(contact.socials));
    this.lastCommunication = contact.lastCommunication;
    this.type = contact.type;
    this.uid = contact.uid;
    this.updatedAt = contact.updatedAt;
    this.crmUrl = contact.crmUrl;
    this.crmName = contact.crmName;
    this.crmId = contact.crmId;
    this.unread = contact.unread;
  }

  copy(Contact contact) {
    this.addresses = convert.jsonDecode(convert.jsonEncode(contact.socials));
    this.company = contact.company;
    this.contacts = contact.contacts;
    this.createdAt = contact.createdAt;
    this.deleted = contact.deleted;
    this.domain = contact.domain;
    this.emails = convert.jsonDecode(convert.jsonEncode(contact.emails));
    this.firstContactDate = contact.firstContactDate;
    this.coworker = contact.coworker;
    this.firstName = contact.firstName;
    this.groups = contact.groups;
    this.id = contact.id;
    this.jobTitle = contact.jobTitle;
    this.lastName = contact.lastName;
    this.leadCreationDate = contact.leadCreationDate;
    this.name = contact.name;
    this.owner = contact.owner;
    this.parentId = contact.parentId;
    this.phoneNumbers =
        convert.jsonDecode(convert.jsonEncode(contact.phoneNumbers));
    this.pictures = convert.jsonDecode(convert.jsonEncode(contact.pictures));
    this.socials = convert.jsonDecode(convert.jsonEncode(contact.socials));
    this.lastCommunication = contact.lastCommunication;
    this.type = contact.type;
    this.uid = contact.uid;
    this.updatedAt = contact.updatedAt;
    this.crmUrl = contact.crmUrl;
    this.crmName = contact.crmName;
    this.crmId = contact.crmId;
    this.unread = contact.unread;
  }

  Contact.build({
    required this.name,
    required this.pictures
  });
}

class ContactsStore extends FusionStore<Contact> {
  ContactsStore(FusionConnection fusionConnection) : super(fusionConnection);

  @override
  storeRecord(Contact record) {
    super.storeRecord(record);
    persist(record);
  }

  persist(Contact record) {
    fusionConnection.db
        .delete('contacts', where: 'id = ?', whereArgs: [record.id]);
    fusionConnection.db.insert('contacts', {
      'id': record.id,
      'company': record.company,
      'deleted': record.deleted! ? 1 : 0,
      'searchString': record.searchString(),
      'firstName': record.firstName,
      'lastName': record.lastName,
      'raw': record.serialize()
    });
  }

  searchPersisted(String query, int limit, int offset,
      Function(List<Contact>, bool, bool fromPhonebook) callback) {
    getDatabasesPath().then((path) {
      openDatabase(join(path, "fusion.db")).then((db) {
        db.query('contacts',
            limit: limit,
            offset: offset,
            where: 'searchString Like ?',
            orderBy: "lastName asc, firstName asc",
            whereArgs: [
              "%" + query + "%"
            ]).then((List<Map<String, dynamic>> results) {
          List<Contact> list = [];
          if (results.isEmpty) {
            db.query('phone_contacts',
                limit: limit,
                offset: offset,
                where: 'searchString Like ?',
                orderBy: "lastName asc, firstName asc",
                whereArgs: [
                  "%" + query + "%"
                ]).then((List<Map<String, dynamic>> res) {
              if (res.isNotEmpty) {
                for (Map<String, dynamic> result in res) {
                  list.add(PhoneContact.unserialize(result['raw']).toContact());
                }
                callback(list, false, true);
              } else {
                callback(list, false, false);
              }
            });
          } else {
            for (Map<String, dynamic> result in results) {
              list.add(Contact.unserialize(result['raw']));
            }
            callback(list, false, false);
          }
        });
      });
    });
  }

  search(String query, int limit, int offset,
      Function(List<Contact>, bool, bool fromPhoneBook) callback) {
    query = query.toLowerCase();
    bool fromPhone = false;
    searchPersisted(query, limit, offset, (contacts, server, phoneBook) {
      callback(contacts, server, phoneBook);
      fromPhone = phoneBook;
    });

    fusionConnection.apiV1Call("get", "/clients/filtered_contacts", {
      'length': offset + limit,
      'search_query': query,
      'sort_by': 'last_name',
      'group_type_filter': 'any',
      'enterprise': false,
    }, callback: (List<dynamic> datas) {
      List<Contact> response = [];

      datas.forEach((dynamic c) {
        Contact contact = Contact(c as Map<String, dynamic>);
        response.add(contact);
        storeRecord(contact);
      });
      if (!fromPhone) callback(response, true, false);
    });
  }

  searchV2(String query, int limit, int offset, fromDialpad,
      Function(List<Contact>, bool, bool fromPhoneBook) callback) {
    query = query.toLowerCase();
    bool fromPhone = false;
    searchPersisted(query, limit, offset, (contacts, server, phoneBook) {
      callback(contacts, server, phoneBook);
      fromPhone = phoneBook;
    });

    fusionConnection.apiV2Call("post", "/contacts/query", {
      "offset": offset,
      "limit": limit,
      "contactFilters": {
        "queries": [query],
        "sorts": [],
        "filters": [],
        "tagFilters": []
      },
    }, callback: (Map<String, dynamic> datas) {
      List<Contact> contacts = getRecords();
      List<Contact> response = [];

      datas['items'].forEach((dynamic c) {
        Contact contact = Contact.fromV2(c as Map<String, dynamic>);
        response.add(contact);
        if (contacts.isEmpty || !fromDialpad) {
          // prevent recurring searching from overwriting current db
          storeRecord(contact);
        }
      });
      if (!fromPhone) callback(response, true, false);
    });
  }

  void save(Contact? edited, Function updateUi) {
    bool usesV2 = fusionConnection.settings.isV2User();
    if (usesV2) {
      fusionConnection
          .apiV2Call("put", "/contacts/${edited!.id}", edited.serverPayloadV2(),
              callback: (Map<String, dynamic> updatedContact) {
        storeRecord(Contact.fromV2(updatedContact));
        updateUi();
      });
    } else {
      fusionConnection.apiV1Call("post", "/clients/filtered_contacts", {
        'contact': edited!.serverPayload()
      }, callback: (List<dynamic> datas) {
        storeRecord(edited);
        updateUi();
      });
    }
  }

  void createContact(Contact contact, Function(Contact) callback) {
    fusionConnection
        .apiV2Call("post", "/contacts/create", contact.serverPayloadV2(),
            callback: (Map<String, dynamic> datas) {
      contact = Contact.fromV2(datas);
      storeRecord(contact);
      callback(contact);
      List<CallHistory> history = fusionConnection.callHistory.getRecords();
      CallHistory? historyItem = history
              .where((element) =>
                  element.fromDid == contact.phoneNumbers[0]['number'] ||
                  element.toDid == contact.phoneNumbers[0]['number'])
              .isNotEmpty
          ? history
              .where((element) =>
                  element.fromDid == contact.phoneNumbers[0]['number'] ||
                  element.toDid == contact.phoneNumbers[0]['number'])
              .first
          : null;
      if (historyItem != null) {
        historyItem.contact = contact;
        fusionConnection.callHistory.storeRecord(historyItem);
      }
    });
  }

  void uploadProfilePic(String type, XFile file, Contact contact,
      Function(Contact) updateUi) async {
    File rotatedImage = await FlutterExifRotation.rotateImage(path: file.path);
    fusionConnection.apiV2Multipart(
        "post", "/client/upload_avatar/$type/${contact.id}", {}, [
      http.MultipartFile.fromBytes("avatar", await rotatedImage.readAsBytes(),
          filename: basename(file.path),
          contentType: MediaType.parse(lookupMimeType(file.path)!))
    ], callback: (Map<String, dynamic> data) {
      if (type == "profile") {
        Coworker coworker = fusionConnection.coworkers
            .lookupCoworker(fusionConnection.getUid())!;
        coworker.url = fusionConnection.mediaServer + data['path'];
        fusionConnection.coworkers.storeRecord(coworker);
      } else {
        contact.pictures
            .add({"url": data['url'], 'fromSourceName': data['from']});
        storeRecord(contact);
      }
      updateUi(contact);
    });
  }

  Future<Contact?> getContactById ({int? fusionId, int? crmId}) async {
    Contact? contact = null;
    //first search persisted
    //then search legacy and v2
    await fusionConnection.apiV2Call("get", "", {}, callback: (){});
    return contact;
  }
}

abstract class ContactType {
  static const PrivateContact = "Private Contact";
  static const Contact = "Contact";
  static const Lead = "Lead";
}
