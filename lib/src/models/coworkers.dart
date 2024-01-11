import 'dart:convert';
import 'package:flutter_gravatar/flutter_gravatar.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_connection.dart';
import 'package:fusion_mobile_revamped/src/models/carbon_date.dart';
import 'package:overlay_support/overlay_support.dart';
import '../utils.dart';
import 'contact.dart';
import 'crm_contact.dart';
import 'fusion_model.dart';
import 'fusion_store.dart';

class Coworker extends FusionModel {
  String email = "";
  String extension = "";
  String uid = "";
  String firstName = "";
  String lastName = "";
  String statusMessage = "";
  String group = "";
  String presence = "";
  String url = "";
  List emails = [];

  serialize() {
    return jsonEncode({
      'email': this.email,
      'extension': this.extension,
      'uid': this.uid,
      'firstName': this.firstName,
      'lastName': this.lastName,
      'statusMessage': this.statusMessage,
      'emails': this.emails,
      'group': this.group,
      'presence': this.presence,
      'url': this.url,
    });
  }

  Coworker(Map<String, dynamic> obj) {
    if (obj['email'].runtimeType == String) email = obj['email'];
    if (obj['first_name'].runtimeType == String) firstName = obj['first_name'];
    if (obj['last_name'].runtimeType == String) lastName = obj['last_name'];
    if (obj['message'].runtimeType == String) statusMessage = obj['message'];
    if (obj['group'].runtimeType == String) group = obj['group'];
    if (obj['presence'].runtimeType == String) presence = obj['presence'];
    extension = obj['user'];
    uid = obj['uid'].toLowerCase();
  }
  
  Coworker.fromV2(Map<String, dynamic> obj){ 
    List pictures =  obj.containsKey('pictures') ? obj['pictures'] : [];
    this.emails = obj.containsKey('emails') ? obj['emails'] : [];
    this.url = obj.containsKey('url') 
      ? obj['url'] 
      : pictures.length > 0 
        ? pictures.last['url'] 
        : "";
    this.firstName = obj.containsKey('firstName') ? obj['firstName'] : "";
    this.lastName = obj.containsKey('lastName') ? obj['lastName'] : "";
    this.statusMessage = obj.containsKey('statusMessage') ? obj['statusMessage'] : "";
    this.group = obj.containsKey('group') ? obj['group'] : "";
    this.presence = obj.containsKey('presence') ? obj['presence'] : "";
    this.extension = obj.containsKey('id') ? obj['id'].split('@')[0] : "";
    this.uid = obj.containsKey('id') ? obj['id'].toLowerCase() : "";
  }

  getName() {
    return (firstName + " " + lastName).trim();
  }

  getDomain() {
    return uid.split('@')[1];
  }

  toContact() {
    Contact c = Contact({
      'addresses': [],
      'company': getDomain(),
      'contacts': [],
      'deleted': false,
      'domain': getDomain(),
      'emails': email != '' ? [{'email': email, 'type': 'Work'}] : [],
      'first_contact_diate': '',
      'first_name': firstName,
      'last_name': lastName,
      'groups': [group],
      'id': uid,
      'job_title': '',
      'lead_creation_date': '',
      'name': firstName + ' ' + lastName,
      'owner': '',
      'parent_id': '',
      'phone_numbers': [{'number': uid, 'type': 'Extension'}],
      'pictures': [{'url': url}],
      'socials': [],
      'type': '',
      'updated_at': {'date': '', 'timezone': '', 'timezone_type': 1},
      'created_at': {'date': '', 'timezone': '', 'timezone_type': 1},
      'crm_url': '',
      'crm_name': 'Fusion',
      'crm_id': uid}
    );
    c.coworker = this;
    return c;
  }

  Coworker.empty() {
    this.email = "";
    this.extension = "";
    this.uid = "";
    this.firstName = "";
    this.lastName = "";
    this.statusMessage = "";
    this.group = "";
    this.presence = "";
    this.url = "";
    this.emails = [];
  }

  @override
  String getId() => this.uid.toLowerCase();
}


class CoworkerSubscription {
  final List<String> _uids;
  final Function(List<Coworker>) _callback;

  CoworkerSubscription(this._uids, this._callback);

  testMatches(Coworker message) {
    return _uids == null || _uids.contains(message.uid);
  }

  sendMatching(List<Coworker> items) {
    List<Coworker> list = [];

    for (Coworker item in items) {
      if (testMatches(item)) {
        list.add(item);
      }
    }

    this._callback(list);
  }
}


class CoworkerStore extends FusionStore<Coworker> {
  String id_field = "uid";
  Map<String, CoworkerSubscription> subscriptions = {};
  CoworkerStore(FusionConnection fusionConnection) : super(fusionConnection);

  hasntLoaded() {
    return getRecords().length == 0;
  }

  subscribe(List<String> uids, Function(List<Coworker>) callback) {
    String name = randomString(20);
    subscriptions[name] = CoworkerSubscription(uids, callback);
    return name;
  }

  clearSubscription(name) {
    if (subscriptions.containsKey(name)) {
      subscriptions.remove(name);
    }
  }

  @override
  storeRecord(Coworker item) {
    super.storeRecord(item);

    for (CoworkerSubscription subscription in subscriptions.values) {
      subscription.sendMatching(getRecords());
    }
  }

  Coworker lookupCoworker(String uid) {
    return lookupRecord(uid.toLowerCase());
  }

  String avatarFor(Coworker c) {
    String url = fusionConnection.settings.avatarForUser(c.uid);
    if (url == fusionConnection.defaultAvatar && c.email != "") {
      try {
        return Gravatar(c.email).imageUrl(defaultImage: avatarUrl(c.firstName, c.lastName)); }
      catch (e) {
        return avatarUrl(c.firstName, c.lastName);
      }
    } else if(url == fusionConnection.defaultAvatar && c.emails.length > 0){
      String mostRecentWorkEmail = c.emails.where((email) => email['type'] == "Work").toList().last['email'];
      try {
        return Gravatar(mostRecentWorkEmail).imageUrl(defaultImage: avatarUrl(c.firstName, c.lastName)); }
      catch (e) {
        return avatarUrl(c.firstName, c.lastName);
      }
    } else if(url != "" && url != fusionConnection.defaultAvatar){
      return url;
    } else {
      return avatarUrl(c.firstName, c.lastName);
    }
  }

  storePresence(String uid, String status, String message) {
    Coworker record = lookupCoworker(uid);
    if (record != null) {
      record.presence = status;
      record.statusMessage = message;
      storeRecord(record);
    }
  }

  search(String query, Function(List<Contact>) callback) {
    Future.delayed(const Duration(milliseconds: 10), ()
    {
      List<Contact> list = [];
      List<Coworker> records = getRecords();
      if(records.isEmpty){
        getCoworkers((p0) => records = p0);
      }
      records.sort((Coworker c1, Coworker c2) {
        return (c1.firstName + c1.lastName)
            .compareTo(c2.firstName + c2.lastName);
      });
      for (Coworker c in records) {
        if ((c.firstName + " " + c.lastName
            + " " + c.email + " " + c.uid).contains(query)) {
          list.add(c.toContact());
        }
      }
      callback(list);
    });
  }

  getCoworkers(Function(List<Coworker>) callback) {
    var future = new Future.delayed(const Duration(milliseconds: 10), () {
      callback(getRecords());
    });
    bool v2User = fusionConnection.settings.isV2User();
    if(v2User){
      fusionConnection.apiV2Call("post","/client/coworkers",
        {},
        callback: (Map<String,dynamic> datas) {
          List<Coworker> response = [];
          if(!datas.containsKey("items")){
            return toast("Couldn't get coworkers list");
          }
          for (Map<String, dynamic> item in datas['items']) {
            Coworker obj = Coworker.fromV2(item);
            obj.url = avatarFor(obj);
            storeRecord(obj);
            response.add(obj);
          }
          callback(response);
        }
      );
    } else {
      fusionConnection.apiV1Call("get","/clients/subscribers", 
        {},
        callback: (List<dynamic> datas) {
          List<Coworker> response = [];
          for (Map<String, dynamic> item in datas) {
            Coworker obj = Coworker(item);
            obj.url = avatarFor(obj);
            storeRecord(obj);
            response.add(obj);
          }
          callback(response);
        }
      );
    }
  }
  
  Coworker getCowworker(String id) {
    return lookupRecord(id.toLowerCase());
  }
}