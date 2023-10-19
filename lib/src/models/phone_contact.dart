import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/fusion_model.dart';
import 'package:sqflite/sql.dart';

import 'contact.dart';
import 'coworkers.dart';
import 'fusion_store.dart';

class PhoneContact extends FusionModel{
  List<dynamic> addresses;
  String company;
  List<dynamic> contacts;
  bool deleted;
  String domain;
  List<dynamic> emails;
  String firstContactDate;
  Coworker coworker;
  String firstName = "";
  List<String> groups;
  String id;
  String jobTitle;
  String lastName = "";
  String leadCreationDate;
  String name;
  String owner;
  String parentId;
  List<dynamic> phoneNumbers;
  List<dynamic> pictures;
  List<dynamic> socials;
  List<dynamic> externalReferences = [];
  Map<String, dynamic> lastCommunication;
  String type;
  String uid;
  String crmUrl;
  String crmName;
  String crmId;
  int unread = 0;
  List<dynamic> fieldValues = [];
  Uint8List profileImage;
  
  @override
  String getId() => this.id;

  PhoneContact(Map<String,dynamic> contactObject) {
    firstName = contactObject['firstName'];
    lastName = contactObject['lastName'];
    company = contactObject['company'];
    jobTitle = contactObject['jobTitle'];
    name = "${contactObject['firstName']} ${contactObject['lastName']}";
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
          "zipPart2": email['zipPart2'],
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
    owner = null;
    if(contactObject.containsKey('imageData')){
      profileImage = _getImageBinary(contactObject['imageData']);
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
      'profileImage': this.profileImage
      }
    );
    return c;
  }

  Uint8List _getImageBinary(dynamicList) {
    if(Platform.isIOS){
      return dynamicList as Uint8List;
    }
    if(Platform.isAndroid){
      if(dynamicList.runtimeType != String){
        List<dynamic>dy = dynamicList as List<dynamic>;
        List<int> intList = dy.cast<int>().toList();
        Uint8List data = Uint8List.fromList(intList);
        return data;
      }
    }
    return null;
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
    @required FusionConnection fusionConnection, 
    @required MethodChannel contactsChannel
  }) : super(fusionConnection, methodChannel: contactsChannel);
  bool syncing = false;

  persist(PhoneContact record, ) {
    List<String> numbers = record.phoneNumbers.map((phoneNumber) => phoneNumber['number']).toList().cast<String>();
    print("MDBM ${record.id}");
    fusionConnection.db.insert('phone_contacts', {
      'id': record.id,
      'company': record.company,
      'searchString': record.searchString(),
      'firstName': record.firstName,
      'lastName': record.lastName,
      'phoneNumbers': numbers.toString(),
      'raw': record.serialize(),
      'profileImage': record.profileImage
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Future<List<PhoneContact>> searchPhoneContact(query) {

  // }

  Future<PhoneContact> searchDb(phoneNumber) async {
    PhoneContact contact;
       
    List<Map<String,dynamic>>results = await fusionConnection.db.query('phone_contacts',                
      where: 'phoneNumbers LIKE (${List.filled([phoneNumber].length, '?').join(',')})',
      orderBy: "lastName asc, firstName asc",
      whereArgs: [[ "%" + phoneNumber + "%"]],
    );

    if(results != null && results.length > 0){
      Map<String,dynamic> result = results.first;
      PhoneContact phoneContact = PhoneContact.unserialize(result['raw']);
      phoneContact.profileImage = result['profileImage'];
      contact = phoneContact;
    }
    return contact;
  }

  Future<PhoneContact> getPhoneContact(phoneNumber) async {
    PhoneContact contact;
    List<PhoneContact> phoneContacts = getRecords();
    if(phoneContacts.isNotEmpty){
      for (PhoneContact phoneContact in phoneContacts) {
        List<String> numbers = phoneContact.phoneNumbers.map((e) => e["number"]).toList();
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
      methodChannel.setMethodCallHandler(_contactsProviderHandler);
  }

  Future _contactsProviderHandler(MethodCall methodCall) async {
    switch(methodCall.method) {
      case "CONTACTS_LOADED":
        List result = [];
        result = jsonDecode(methodCall.arguments);
        for (var c in result) {
          PhoneContact contact = PhoneContact(c);
          storeRecord(contact);
          persist(contact);
        }
        syncing = false;
        break;
      default:
         print("contacts default");
    }
  }

  void syncPhoneContacts(){
    syncing = true;
    try {
      if(Platform.isIOS){
        methodChannel.invokeMethod('getContacts');
      } else {
        methodChannel.invokeMethod('syncContacts');
      }
    } on PlatformException catch (e) {
      print("MDBM syncPhoneContacts error $e");
    }

  }


  Future<List<PhoneContact>> getAdderssBookContacts(String query,{bool pullNewContacts}) async{
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
            syncPhoneContacts();
            // try {
            //   List result = [];
            //   if(Platform.isIOS){
            //     result = await methodChannel.invokeMethod('getContacts');
            //   } else {
            //     var data = await methodChannel.invokeMethod('getContacts');
            //     result = jsonDecode(data);
            //   }
            //   for (var c in result) {
            //     PhoneContact contact = PhoneContact(c);
            //     storeRecord(contact);
            //     persist(contact);
            //     contacts.add(contact);
            //   }
            // } on PlatformException catch (e) {
            //   print("MDBM getAdderssBookContacts error $e");
            // }
          }
        });
    }
    return contacts;
  }
}