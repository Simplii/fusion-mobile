import 'dart:convert';

import '../backend/fusion_connection.dart';
import 'contact.dart';

class UserSettings {
  Map<String, dynamic> options = {"avatars": {}};
  Map<String, dynamic> subscriber = {'callid_nmbr': '', 'user': ''};
  final FusionConnection _fusionConnection;
  String myOutboundCallerId = "";
  bool isDynamicDialingDept = false;
  bool dynamicDialingIsActive = false;
  UserSettings(this._fusionConnection);
  String myCellPhoneNumber = "";
  bool usesCarrier = false;
  String devices = "";
  bool dnd = false;
  bool forceDispositionEnabled = false;
  
  myContact() {
    if (subscriber['first_name'] == null) subscriber['first_name'] = "";
    if (subscriber['last_name'] == null) subscriber['last_name'] = "";
    return Contact({
      'addresses': [],
      'company': options['domain'],
      'contacts': [],
      'deleted': false,
      'domain': options['domain'],
      'emails': subscriber['email'].runtimeType == String
          ? [{'email': subscriber['email'], 'type': 'Work'}]
          : [],
      'first_contact_diate': '',
      'first_name': subscriber['first_name'],
      'last_name': subscriber['last_name'],
      'groups': [],
      'id': '-1',
      'job_title': '',
      'lead_creation_date': '',
      'name': subscriber['first_name'] + ' ' + subscriber['last_name'],
      'owner': '',
      'parent_id': '',
      'phone_numbers': [],
      'pictures': [],
      'socials': [],
      'type': '',
      'updated_at': {'date': '', 'timezone': '', 'timezone_type': 1},
      'created_at': {'date': '', 'timezone': '', 'timezone_type': 1},
      'crm_url': '',
      'crm_name': 'Fusion',
      'crm_id': ''
    });
  }

  setOptions(Map<String, dynamic> opts) {
    options = opts;
  }

  setSubscriber(Map<String, dynamic> me) {
    subscriber = me;
  }

  lookupSubscriber() {
    _fusionConnection.nsApiCall(
        'subscriber',
        'read',
        {'uid': _fusionConnection.getUid()},
        callback: (Map<String, dynamic> data) {
          if (data.containsKey('subscriber') && data['subscriber'].containsKey('user')) {
            subscriber = data['subscriber'];
            if (subscriber['callid_nmbr'] == null)
              subscriber['callid_nmbr'] = '';
            // netsapians returns empty object if last name not provided
            if(subscriber['last_name'].runtimeType != String ){
              subscriber['last_name'] = '';
            }
          }
        });
  }

  String userScope() {
    return subscriber['scope'];
  }

  bool hasFusionPlus() {
    return options['registration'] != null
        && options['registration']['domain_package_id'].toString() == "8";
  }

  bool hasManagerPermissions() {
    String scope = userScope();
    return scope == 'Office Manager' || scope == 'Super User';
  }

  String avatarForUser(String uid) {
    if (options['avatars'].containsKey(uid.toLowerCase())) {
      String serverRoot = this.isV2User() 
        ? "https://fusion-media.sfo2.digitaloceanspaces.com"
        : "http://fusioncom.co";
      return serverRoot + options['avatars'][uid.toLowerCase()];
    }
    else {
      return _fusionConnection.defaultAvatar;
    }
  }

  String myAvatar() {
    return avatarForUser(_fusionConnection.getUid());
  }

  List<Map<String, dynamic>> crmData() {
    return (options['crm_features'] as Map<String, dynamic>).values as List<Map<String, dynamic>>;
  }

  String crmIcon(crmName) {
    List<Map<String, dynamic>> crms = crmData();
    for (Map<String, dynamic> crmData in crms) {
      if (crmData['CRM_NAME'] == crmName) {
        return crmData['CRM_ICON'] as String;
      }
    }
    throw "Crm not found (" + crmName + ")";
  }

  List<dynamic> enabledFeatures() {
    return options['client']['options'];
  }

  bool isFeatureEnabled(featureName) {
    return enabledFeatures().contains(featureName);
  }

  List<String> parkLines() {
    return options['park_lines'] as List<String>;
  }

  List<Map<String, dynamic>> userSmsNumbers() {
    List<Map<String, dynamic>> numbers = [];

    for (Map<String, dynamic> user in options['sms_users']) {
      numbers.add({'phoneNumber': options['phone_number_id'],
                    'isMMS': options['is_mms']
                  });
    }

    return numbers;
  }

  setOutboundDid(String newDid, bool isDepartment) {
    myOutboundCallerId = newDid;
    isDynamicDialingDept = isDepartment;
    _fusionConnection.apiV2Call("post", "/clients/setOutboundDid/" + newDid, {
      "dynamicDialingDepartment" : isDepartment
    },
        callback: (Map<String, dynamic> datas) {
          Map<String, dynamic> oldSubscriber = subscriber;
          oldSubscriber['callid_nmbr'] = newDid;
          setSubscriber(oldSubscriber);
        });
  }

  domainPrefixes() {
    return options["prefixes"];
  }

  bool isV2User(){
    return options['uses_v2'] != null && options['uses_v2'] == true;
  }

  void setMyUserInfo({
    String outboundCallerId, 
    bool isDepartment, 
    bool dynamicDialingEnabledForDomain,
    String cellPhoneNumber,
    bool useCarrier,
    String simParams,
    bool dndIsOn,
    bool forceDispoEnabled,
    }) {
      usesCarrier = useCarrier;
      myCellPhoneNumber = cellPhoneNumber;
      myOutboundCallerId = outboundCallerId;
      isDynamicDialingDept = isDepartment;
      devices = simParams;
      dynamicDialingIsActive = isFeatureEnabled("Dynamic Dialing");
      dnd = dndIsOn;
      forceDispositionEnabled = forceDispoEnabled;
  }

  bool updateUserSettings (List<SettingsPayload> settings) {
    bool ret = false;
    _fusionConnection.apiV1Call("post", "/clients/user_settings", {
      "uid" : _fusionConnection.getUid(),
      "settings" : [...settings],
      },
      callback: (Map<String,dynamic> data){
        if(data["success"] != null){
          settings.forEach((SettingsPayload setting){
            if(setting.setting == "uses_carrier"){
              usesCarrier = setting.value.isNotEmpty;
            }
            if(setting.setting == "cell_phone_number"){
              myCellPhoneNumber = setting.value;
            }
            if(setting.setting == "fm_on_dnd"){
              dnd = setting.value == "true" ? true : false;
            }
          },);
          ret = true;
        } 
      }
    );
    return ret;
  }
}

class SettingsPayload {
  String uid;
  String setting;
  String value;
  SettingsPayload(this.uid,this.setting,this.value);
  Map<String,dynamic> toJson(){
    return {
      "uid" : uid,
      "setting": setting,
      "value": value
    };
  }
}