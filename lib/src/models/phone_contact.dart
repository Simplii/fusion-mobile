import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/fusion_model.dart';
import 'package:fusion_mobile_revamped/src/utils.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sql.dart';

import 'contact.dart';
import 'coworkers.dart';
import 'fusion_store.dart';

class PhoneContact extends FusionModel{
  List<dynamic> addresses = [];
  String company = "";
  List<dynamic> contacts = [];
  bool deleted = false;
  String domain = "";
  List<dynamic> emails = [];
  String firstContactDate = "";
  Coworker? coworker = null;
  String firstName = "";
  List<String> groups = [];
  String id = "";
  String jobTitle = "";
  String lastName = "";
  String leadCreationDate = "";
  String name = "";
  String owner = "";
  String parentId = "";
  List<dynamic> phoneNumbers = [];
  List<dynamic> pictures = [];
  List<dynamic> socials = [];
  List<dynamic> externalReferences = [];
  Map<String, dynamic> lastCommunication = {};
  String type = "";
  String uid = "";
  String crmUrl = "";
  String crmName = "";
  String crmId ="";
  int unread = 0;
  List<dynamic> fieldValues = [];
  Uint8List? profileImage;
  
  @override
  String getId() => this.id;

  PhoneContact(Map<String,dynamic> contactObject) {
    firstName = contactObject['firstName'];
    lastName = contactObject['lastName'];
    company = contactObject['company'] ?? "";
    jobTitle = contactObject['jobTitle'] ?? "";
    name = contactObject['name'];
    phoneNumbers = [];
    if(contactObject['phoneNumbers'] != null){
      for (var number in contactObject['phoneNumbers']) {
        this.phoneNumbers.add({
          "number": number['number'].toString(),
          "smsCapable": number['smsCapable'],
          "type": number['type']
        });
      } 
    }
    externalReferences = [];
    deleted = false;
    groups = [];
    id = contactObject['id'];
    type = ContactType.PrivateContact;
    fieldValues = [];

    addresses = [];
    if(contactObject['addresses'] != null){
      for (var email in contactObject['addresses']) {
        addresses.add({
          "address1": email['address'],
          "address2": email['address2'],
          "city": email['city'],
          "state": email['state'],
          "zip": email['zip'],
          "zipPart2": email['zipPart2'] ?? "",
          "country": email['country'],
          "name": email['name'],
          "zip-2": email['zip-2'],
          "id": email['id'],
          "type": email['type']
        });
      } 
    }
    emails = [];
    if(contactObject['emails'] != null){
      for (var email in contactObject['emails']) {
        this.emails.add({
          "email": email['email'],
          "id": email['id'],
          "type": email['type']
        });
      } 
    }
    pictures = [];
    socials = [];
    owner = "";
    if(contactObject.containsKey('profileImage')){
      profileImage = getImageBinary(contactObject['profileImage']);
    }
    if(name.trim().isEmpty){
      firstName = "Unknown";
      lastName = "Unknown";
      name = "Unknown Contact";
    }
  }

  toContact() {
    Contact c = Contact({
      'addresses': addresses,
      'company':  company,
      'deleted': false,
      'domain': null,
      'emails': emails,
      'first_contact_diate': '',
      'first_name': firstName,
      'last_name': lastName,
      'groups': [],
      'id': id,
      'job_title': jobTitle,
      'name': name,
      'owner': '',
      'parent_id': '',
      'phone_numbers': phoneNumbers,
      'pictures': pictures,
      'socials': socials,
      'type': type,
      'crm_url': '',
      'crm_name': '',
      'crm_id': '',
      'coworker': null,
      'profileImage': this.profileImage,
      'created_at': null,
      'updated_at': null
      }
    );
    return c;
  }

  serialize() {
    return jsonEncode({
      'addresses': this.addresses,
      'company': this.company,
      'contacts': this.contacts,
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
      'crmUrl': this.crmUrl,
      'crmName': this.crmName,
      'crmId': this.crmId,
      'unread': this.unread,
      'profileImage': this.profileImage
    });
  }

  PhoneContact.unserialize(String data) {
    Map<String, dynamic> obj = jsonDecode(data);
    this.addresses = obj['addresses'];
    this.company = obj['company'];
    this.contacts = obj['contacts'];
    this.deleted = obj['deleted'];
    this.domain = obj['domain'];
    this.emails = obj['emails'];
    this.firstContactDate = obj['firstContactDate'];
    this.coworker = obj['coworker'] != '' && obj['coworker'] != null 
      ? Coworker(jsonDecode(obj['coworker']))
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
    this.crmUrl = obj['crmUrl'];
    this.crmName = obj['crmName'];
    this.crmId = obj['crmId'];
    this.unread = obj['unread'];
    this.profileImage = getImageBinary(obj['profileImage']);
  }

   searchString() {
    List<String> list = [company, firstName, lastName];
    for (Map<String, dynamic> number in phoneNumbers) {
      list.add(number['number'].toString());
    }
    for (Map<String, dynamic> email in emails) {
      list.add(email['email'].toString());
    }
    return list.join(' ');
  }

}

class PhoneContactsStore extends FusionStore<PhoneContact> {
  PhoneContactsStore({
    required FusionConnection fusionConnection, 
    required MethodChannel contactsChannel
  }) : super(fusionConnection, methodChannel: contactsChannel);
  bool syncing = false;
  bool initSync = false;
  Function? updateView;

  persist(PhoneContact record, ) {
    List<String> numbers = record.phoneNumbers.map((phoneNumber) => phoneNumber['number']).toList().cast<String>();
    fusionConnection.db.insert('phone_contacts', {
      'id': record.id,
      'company': record.company,
      'searchString': record.searchString(),
      'firstName': record.firstName,
      'lastName': record.lastName,
      'phoneNumbers': numbers.toString(),
      'raw': record.serialize(),
      'profileImage': record.profileImage
    }, conflictAlgorithm: ConflictAlgorithm.replace).then((value) => value);
  }

  void toUpdateView (Function setStateFunc){
    updateView = setStateFunc;
  }

  Future<PhoneContact?> searchDb(String phoneNumber) async {
    PhoneContact? contact;
       
    List<Map<String,dynamic>>results = await fusionConnection.db.query('phone_contacts',                
      // where: 'phoneNumbers LIKE (${List.filled([phoneNumber].length, '?').join(',')})',
      where: 'searchString LIKE ?',
      orderBy: "lastName asc, firstName asc",
      // whereArgs: [[ "%" + phoneNumber + "%"]],
      whereArgs: ["%$phoneNumber%"],
    );
      
    if(results != null && results.length > 0){
      Map<String,dynamic> result = results.first;
      PhoneContact phoneContact = PhoneContact.unserialize(result['raw']);
      phoneContact.profileImage = result['profileImage'];
      contact = phoneContact;
    }
    return contact;
  }

  Future<PhoneContact?> getPhoneContact(phoneNumber) async {
    PhoneContact? contact;
    List<PhoneContact> phoneContacts = getRecords();
    if(phoneContacts.isNotEmpty){
      for (PhoneContact phoneContact in phoneContacts) {
        List<String> numbers = phoneContact.phoneNumbers.map((e) => e["number"]).toList().cast<String>();
        if(numbers.contains(phoneNumber)){
          contact = phoneContact;
        }
      }
    } else {
      contact = await searchDb(phoneNumber);
    }
            
    return contact;
  }
  
  setup(){
      methodChannel?.setMethodCallHandler(_contactsProviderHandler);
  }

  Future _contactsProviderHandler(MethodCall methodCall) async {
    switch(methodCall.method) {
      case "CONTACTS_LOADED":
        List result = [];
        result = Platform.isAndroid 
          ? jsonDecode(methodCall.arguments)
          : methodCall.arguments;
        for (var c in result) {
          PhoneContact contact = Platform.isAndroid 
            ? PhoneContact(c)
            : PhoneContact(Map<String, dynamic>.from(c));
          storeRecord(contact);
          persist(contact);
        }
        syncing = false;
        initSync = false;
        if(updateView != null)
          updateView!();
        break;
      default:
         print("contacts default");
    }
  }

  void syncPhoneContacts() async {
    final PermissionStatus status = await Permission.contacts.status;
    if(status.isGranted){
      if(!syncing){
        syncing = true;
        try {
          methodChannel?.invokeMethod('syncContacts');
        } on PlatformException catch (e) {
          print("MDBM syncPhoneContacts error $e");
        }
      } else {
        toast("contacts sync in progress");
      }
    }
  }


  Future<List<PhoneContact>> getAdderssBookContacts(String query) async{
    List<PhoneContact> contacts = getRecords();  
    if(contacts.isNotEmpty && query.isEmpty){
      return contacts;
    } else {
        await fusionConnection.db.query('phone_contacts',
            where: 'searchString Like ?',
            whereArgs: ["%" + query + "%"],
            orderBy: "lastName asc, firstName asc",
        ).then((List<Map<String, dynamic>> results) async {
          List<PhoneContact> list = [];

          for (Map<String, dynamic> result in results) {
            PhoneContact phoneContact = PhoneContact.unserialize(result['raw']);
            phoneContact.profileImage = result['profileImage'];
            storeRecord(phoneContact);
            list.add(phoneContact);
          }
          contacts = list;

          if(list.isEmpty && query.isEmpty && !syncing){
            initSync = true;
            syncPhoneContacts();
          }
        });
    }
    return contacts;
  }
}