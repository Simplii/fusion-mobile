import 'dart:async';
import 'dart:convert' as convert;
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:fusion_mobile_revamped/src/backend/fusion_stream_events.dart';
import 'package:fusion_mobile_revamped/src/models/contact_fields.dart';
import 'package:fusion_mobile_revamped/src/models/custom_fields.dart';
import 'package:fusion_mobile_revamped/src/models/dids.dart';
import 'package:fusion_mobile_revamped/src/models/park_lines.dart';
import 'package:fusion_mobile_revamped/src/models/phone_contact.dart';
import 'package:fusion_mobile_revamped/src/models/quick_response.dart';
import 'package:fusion_mobile_revamped/src/models/timeline_items.dart';
import 'package:fusion_mobile_revamped/src/models/unreads.dart';
import 'package:fusion_mobile_revamped/src/models/voicemails.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:fusion_mobile_revamped/src/models/call_history.dart';
import 'package:fusion_mobile_revamped/src/models/callpop_info.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/coworkers.dart';
import 'package:fusion_mobile_revamped/src/models/crm_contact.dart';
import 'package:fusion_mobile_revamped/src/models/integrated_contacts.dart';
import 'package:fusion_mobile_revamped/src/models/messages.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:fusion_mobile_revamped/src/models/user_settings.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../utils.dart';
import 'softphone.dart';
import 'dart:developer' as developer;

class FusionConnection {
  String _TAG = "MDBM FUSIONCONNECTION";
  String _extension = '';
  String _username = '';
  // String _password = '';
  String _domain = '';
  late SharedPreferences sharedPreferences;
  // Map<String, bool> _heartbeats = {};
  late CrmContactsStore crmContacts;
  late ContactsStore contacts;
  late PhoneContactsStore phoneContacts;
  late CallpopInfoStore callpopInfos;
  late WebSocketChannel socketChannel;
  late SMSConversationsStore conversations;
  late SMSMessagesStore messages;
  late UserSettings settings;
  late SMSDepartmentsStore smsDepartments;
  late CallHistoryStore callHistory;
  late CoworkerStore coworkers;
  late IntegratedContactsStore integratedContacts;
  late ContactFieldStore contactFields;
  late TimelineItemStore timelineItems;
  late ParkLineStore parkLines;
  late VoicemailStore voicemails;
  late DidStore dids;
  late UnreadsStore unreadMessages;
  late QuickResponsesStore quickResponses;
  late CustomFieldStore customFields;
  late Database db;
  String? _pushkitToken;
  Softphone? _softphone;
  Function _onLogOut = () {};
  Function _refreshUi = () {};
  Map<String, bool> received_smses = {};
  Connectivity connectivity = Connectivity();
  ConnectivityResult connectivityResult = ConnectivityResult.none;
  bool internetAvailable = true;
  StreamSubscription? _wsStream;
  static final String host = "fusioncom.co";
  // static final String host = "zaid-fusion-dev.fusioncomm.net";
  String serverRoot = "http://$host";
  StreamController<FusionStreamEventData> fusionStreamEvents =
      StreamController.broadcast();
  String mediaServer = "https://fusion-media.sfo2.digitaloceanspaces.com";
  String defaultAvatar = "https://$host/img/defaultuser.png";
  static const MethodChannel contactsChannel =
      MethodChannel('net.fusioncomm.ios/contacts');
  static const MethodChannel conversationsChannel =
      MethodChannel('channel/conversations');
  static bool isInternetActive = false;
  String _token = "";
  String _signature = "";
  bool loggingOut = false;
  FusionStreamEvents streamEvents = FusionStreamEvents();
  // Switched fusion connection to Singleton so we don't have to pass it down each widget
  FusionConnection._internal() {
    crmContacts = CrmContactsStore(this);
    integratedContacts = IntegratedContactsStore(this);
    contacts = ContactsStore(this);
    callpopInfos = CallpopInfoStore(this);
    conversations = SMSConversationsStore(this);
    messages = SMSMessagesStore(this);
    settings = UserSettings(this);
    smsDepartments = SMSDepartmentsStore(this);
    callHistory = CallHistoryStore(this);
    coworkers = CoworkerStore(this);
    timelineItems = TimelineItemStore(this);
    contactFields = ContactFieldStore(this);
    customFields = CustomFieldStore(this);
    voicemails = VoicemailStore(this);
    parkLines = ParkLineStore(this);
    dids = DidStore(this);
    unreadMessages = UnreadsStore(this);
    quickResponses = QuickResponsesStore(this);
    phoneContacts = PhoneContactsStore(
        fusionConnection: this, contactsChannel: contactsChannel);
    phoneContacts.setup();
    getDatabase();
  }

  static final FusionConnection instance = FusionConnection._internal();
  factory FusionConnection({required SharedPreferences sharedPreferences}) {
    instance.sharedPreferences = sharedPreferences;
    return instance;
  }

  refreshUnreads() {
    unreadMessages
        .getUnreads((List<DepartmentUnreadRecord> messages, bool fromServer) {
      _refreshUi();
    });
  }

  setSoftphone(Softphone? softphone) {
    _softphone = softphone;
  }

  onLogOut(Function callback) {
    _onLogOut = callback;
  }

  setPushkitToken(String? token) {
    _pushkitToken = token;
  }

  _clearDataStores() {
    crmContacts.clearRecords();
    contacts.clearRecords();
    callpopInfos.clearRecords();
    conversations.clearRecords();
    messages.clearRecords();
    smsDepartments.clearRecords();
    callHistory.clearRecords();
    coworkers.clearRecords();
    integratedContacts.clearRecords();
    contactFields.clearRecords();
    customFields.clearRecords();
    timelineItems.clearRecords();
    parkLines.clearRecords();
    voicemails.clearRecords();
    dids.clearRecords();
    unreadMessages.clearRecords();
    quickResponses.clearRecords();
    phoneContacts.clearRecords();
    settings.clearRecord();
  }

  logOut() async {
    loggingOut = true;
    _wsStream?.cancel();
    fusionStreamEvents = StreamController.broadcast();
    _softphone?.unregisterLinphone();
    String? FBtoken = await FirebaseMessaging.instance.getToken();
    if (_pushkitToken != null) {
      await apiV1Call(
          "delete", "/clients/device_token", {"token": _pushkitToken});
    }
    await apiV1Call("delete", "/clients/device_token", {
      "token": FBtoken,
      "pn_tok": _pushkitToken,
    });
    await apiV1Call("get", "/log_out", {});
    _username = '';
    if (_softphone != null) {
      _softphone?.stopInbound();
      _softphone?.close();
      setSoftphone(null);
    }
    _clearDataStores();
    _token = "";
    _signature = "";
    _onLogOut();
  }

  // need to change this in the future to use database versioning and run migrations
  getDatabase() {
    getDatabasesPath().then((String path) {
      openDatabase(p.join(path, "fusion.db"), version: 1, onOpen: (db) {
        print(db.execute('''
          CREATE TABLE IF NOT EXISTS sms_conversation(
          conversationId int,
          id TEXT PRIMARY key,
          groupName TEXT,
          isGroup int,
          lastContactTime int,
          searchString TEXT,
          number TEXT,
          myNumber TEXT,
          unread int,
          raw BLOB,
          isBroadcast TEXT,
          filters BLOB,
          assigneeUid TEXT
          );'''));

        print(db.execute('''
          CREATE TABLE IF NOT EXISTS sms_message(
          id TEXT PRIMARY key,
          `from` TEXT,
          fromMe int,
          media int,
          message TEXT,
          mime TEXT,
          read int,
          time int,
          `to` STRING,
          user STRING,
          raw BLOB,
          broadcastConvoId int,
          errorMessage TEXT
          );'''));

        print(db.execute('''
          CREATE TABLE IF NOT EXISTS call_history(
          cdrIdHash TEXT PRIMARY key,
          id TEXT,
          startTime TEXT,
          toDid TEXT,
          fromDid TEXT,
          `to` TEXT,
          `from` TEXT,
          duration int,
          recordingUrl TEXT,
          direction TEXT,
          callerId TEXT,
          missed TEXT,
          contacts BLOB,
          coworker BLOB,
          phoneContact BLOB,
          queue TEXT
          );'''));

        print(db.execute('''
          CREATE TABLE IF NOT EXISTS contacts(
          id TEXT PRIMARY key,
          company TEXT,
          deleted int,
          searchString TEXT,
          firstName TEXT,
          lastName TEXT,
          raw BLOB
          );
          '''));
        print(db.execute('''
          CREATE TABLE IF NOT EXISTS phone_contacts(
          id TEXT PRIMARY key,
          company TEXT,
          deleted int,
          searchString TEXT,
          phoneNumbers TEXT,
          firstName TEXT,
          lastName TEXT,
          raw BLOB,
          profileImage BLOB
          );
          '''));
      }).then((Database db) {
        db
            .rawQuery('SELECT conversationId FROM sms_conversation')
            .then((value) => null)
            .catchError((error) => {
                  db
                      .rawQuery(
                          'ALTER TABLE sms_conversation ADD COLUMN conversationId')
                      .then((value) => null)
                      .catchError((onError) => print(
                          "MyDebugMessage db couldn't create conversationId col"))
                });
        db
            .rawQuery('SELECT phoneContact FROM call_history')
            .then((value) => null)
            .catchError((error) => {
                  db
                      .rawQuery(
                          'ALTER TABLE call_history ADD COLUMN phoneContact')
                      .then((value) => null)
                      .catchError((onError) => print(
                          "MyDebugMessage db couldn't create phoneContact col"))
                });
        db
            .rawQuery('SELECT queue FROM call_history')
            .then((value) => null)
            .catchError((error) => {
                  db
                      .rawQuery('ALTER TABLE call_history ADD COLUMN queue')
                      .then((value) => null)
                      .catchError((onError) =>
                          print("MyDebugMessage db couldn't create queue col"))
                });
        db
            .rawQuery('SELECT isBroadcast FROM sms_conversation')
            .then((value) => null)
            .catchError((error) => {
                  db
                      .rawQuery(
                          'ALTER TABLE sms_conversation ADD COLUMN isBroadcast')
                      .then((value) => null)
                      .catchError((onError) => print(
                          "MyDebugMessage db couldn't create isBroadcast col"))
                });
        db
            .rawQuery('SELECT filters FROM sms_conversation')
            .then((value) => null)
            .catchError((error) => {
                  db
                      .rawQuery(
                          'ALTER TABLE sms_conversation ADD COLUMN filters')
                      .then((value) => null)
                      .catchError((onError) => print(
                          "MyDebugMessage db couldn't create filters col"))
                });
        db
            .rawQuery('SELECT broadcastConvoId FROM sms_message')
            .then((value) => null)
            .catchError((error) => {
                  db
                      .rawQuery(
                          'ALTER TABLE sms_message ADD COLUMN broadcastConvoId')
                      .then((value) => null)
                      .catchError((onError) => print(
                          "MyDebugMessage db couldn't create broadcastConvoId col"))
                });
        db
            .rawQuery('SELECT assigneeUid FROM sms_conversation')
            .then((value) => null)
            .catchError((error) => {
                  db
                      .rawQuery(
                          'ALTER TABLE sms_conversation ADD COLUMN assigneeUid')
                      .then((value) => null)
                      .catchError((onError) => print(
                          "MyDebugMessage db couldn't create assigneeUid col"))
                });
        db
            .rawQuery('SELECT errorMessage FROM sms_message')
            .then((value) => null)
            .catchError((error) => {
                  db
                      .rawQuery(
                          'ALTER TABLE sms_message ADD COLUMN errorMessage')
                      .then((value) => null)
                      .catchError(() => print(
                          "MyDebugMessage db couldn't create errorMessage col"))
                });
        this.db = db;
      }).catchError((error) {});
    });
  }

  nsApiCall(String object, String action, Map<String, dynamic> data,
      {required Function callback, int retryCount = 0}) async {
    var client = http.Client();
    try {
      data['action'] = action;
      data['object'] = object;
      data['username'] = _username;
      if (!data.containsKey("domain") || data['domain'] == "") {
        data['domain'] = _domain;
      }
      Uri url = Uri.parse('https://$host/api/v1/clients/api_request');

      String requestBody = convert.jsonEncode(data);
      String _authToken = generateMd5(
          "$_token:$_username:/api/v1/clients/api_request:${requestBody.isEmpty ? "" : requestBody}:$_signature");

      Map<String, String> headers = {
        "X-fusion-uid": _username,
        "Authorization": "Bearer $_authToken"
      };
      headers["Content-Type"] = "application/json";

      var uriResponse =
          await client.post(url, headers: headers, body: requestBody);
      Map<String, dynamic>? jsonResponse = {};
      try {
        jsonResponse =
            convert.jsonDecode(uriResponse.body) as Map<String, dynamic>?;
      } catch (e) {}
      // print(
      //     "MDBM nsapi status code=${uriResponse.statusCode} body=${uriResponse.body} authtoken=$_authToken");
      if (uriResponse.statusCode == 401 &&
          uriResponse.headers.containsKey("x-fusion-signature")) {
        if (uriResponse.headers["x-fusion-signature"] != null &&
            uriResponse.headers["x-fusion-signature"] != _signature) {
          developer.log("nsApiCall new signature", name: _TAG);
          _signature = uriResponse.headers["x-fusion-signature"]!;
          sharedPreferences.setString("signature", _signature);
          if (retryCount >= 5) {
            developer.log("nsApiCall retried $url 5 times", name: _TAG);
          } else {
            await Future.delayed(Duration(seconds: 1), () async {
              developer.log("nsApiCall retry future", name: _TAG);
              await nsApiCall(object, action, data,
                  callback: callback, retryCount: retryCount + 1);
            });
          }
        }
      } else {
        // developer.log(
        //   "NS_API_Resp ${jsonResponse} $action $object",
        //   name: _TAG,
        // );
        callback(jsonResponse);
      }
    } finally {
      client.close();
    }
  }

  apiV1Call(String method, String route, Map<String, dynamic> data,
      {Function? callback, Function? onError, int retryCount = 0}) async {
    var client = http.Client();
    try {
      Function fn = {
        'post': client.post,
        'get': client.get,
        'patch': client.patch,
        'put': client.put,
        'delete': client.delete
      }[method.toLowerCase()]!;

      Map<Symbol, dynamic> args = {};
      String urlParams = "";
      if (method.toLowerCase() == 'get' && data.isNotEmpty) {
        urlParams = "?";
        for (String key in data.keys) {
          RegExp reg = RegExp((r'[^\x20-\x7E]'));
          urlParams += key +
              "=" +
              Uri.encodeQueryComponent(
                  data[key].toString().trim().replaceAll(reg, '')) +
              '&';
        }
      }
      Uri url = Uri.parse('https://$host/api/v1' + route + urlParams);
      String requestBody = convert.jsonEncode(data);
      String _authToken = method == "get" || requestBody.isEmpty
          ? generateMd5(
              "$_token:$_username:/api/v1$route$urlParams::$_signature")
          : generateMd5(
              "$_token:$_username:/api/v1$route$urlParams:$requestBody:$_signature");

      Map<String, String> headers = {
        "X-fusion-uid": _username,
        "Authorization": "Bearer $_authToken"
      };
      if (method.toLowerCase() != 'get') {
        args[#body] = requestBody;
        headers["Content-Type"] = "application/json";
      }

      args[#headers] = headers;
      http.Response? uriResponse;
      try {
        uriResponse = await Function.apply(fn, [url], args);
      } catch (e) {
        developer.log("apiCallV1 error", name: _TAG, error: e);
      }

      if (uriResponse?.statusCode == 401) {
        //unauthorized request, checking if signature has changed
        if (uriResponse!.headers.containsKey("x-fusion-signature") &&
            uriResponse.headers["x-fusion-signature"] != _signature) {
          //fusion signature was updated
          developer.log("apiv1 new signature url=$url", name: _TAG);
          _signature = uriResponse.headers["x-fusion-signature"]!;
          sharedPreferences.setString("signature", _signature);
        } else {
          print(
              "$_TAG apiv1 auth failed ${uriResponse.headers} $_signature $_username $_token");
          print(
              "$_TAG apiv1 auth failed statuscode=${uriResponse.statusCode} ${uriResponse.body}");
          print(
              "$_TAG apiv1 auth to hash $_token:$_username:/api/v1$route$urlParams:${requestBody.isEmpty ? requestBody : ""}:$_signature");
        }
        if (retryCount >= 5) {
          developer.log("apiv1 retried $url 5 times", name: _TAG);
          if (onError != null) {
            onError();
          }
        } else {
          await Future.delayed(Duration(seconds: 1), () async {
            developer.log("apiv1 retry future url=$url", name: _TAG);

            await apiV1Call(method, route, data,
                onError: onError,
                callback: callback,
                retryCount: retryCount + 1);
          });
        }
      } else {
        if (uriResponse?.statusCode != 200) {
          developer.log(
              "apiv1 request failing $method $url ${uriResponse?.statusCode} retryCount=$retryCount",
              name: _TAG);
        } else {
          var jsonResponse = convert.jsonDecode(uriResponse?.body ?? "");
          developer.log("apiv1 $method $url ${uriResponse?.statusCode}",
              name: _TAG);
          if (callback != null) callback(jsonResponse);
        }
      }
    } finally {
      client.close();
    }
  }

  apiV2Call(String method, String route, Map<String, dynamic> data,
      {Function? callback, Function? onError, int retryCount = 0}) async {
    var client = http.Client();
    try {
      Function fn = {
        'post': client.post,
        'get': client.get,
        'patch': client.patch,
        'put': client.put,
        'delete': client.delete
      }[method.toLowerCase()]!;
      Map<Symbol, dynamic> args = {};
      String urlParams = "";

      if (method.toLowerCase() == 'get') {
        urlParams = data.isNotEmpty ? "?" : "";
        for (String key in data.keys) {
          RegExp reg = RegExp((r'[^\x20-\x7E]'));
          urlParams += key +
              "=" +
              Uri.encodeQueryComponent(
                  data[key].toString().trim().replaceAll(reg, '')) +
              '&';
        }
        if (urlParams.endsWith("&")) {
          urlParams = urlParams.substring(0, urlParams.length - 1);
        }
      }
      Uri url = Uri.parse('https://$host/api/v2' + route + urlParams);

      String requestBody = convert.jsonEncode(data);
      String _authToken = method == "get" || requestBody.isEmpty
          ? generateMd5(
              "$_token:$_username:/api/v2$route$urlParams::$_signature")
          : generateMd5(
              "$_token:$_username:/api/v2$route$urlParams:$requestBody:$_signature");
      Map<String, String> headers = {
        "X-fusion-uid": _username,
        "Authorization": "Bearer $_authToken"
      };

      if (method.toLowerCase() != 'get') {
        args[#body] = requestBody;
        headers["Content-Type"] = "application/json";
      }

      args[#headers] = headers;
      http.Response? uriResponse;
      try {
        uriResponse = await Function.apply(fn, [url], args);
      } catch (e) {
        toast("${e}");
        developer.log("apiCallV2 error", name: _TAG, error: e);
      }
      if (uriResponse?.statusCode == 401) {
        // unauthorized request, checking if signature has changed
        if (uriResponse!.headers.containsKey("x-fusion-signature") &&
            uriResponse.headers["x-fusion-signature"] != _signature) {
          // fusion signature was updated
          developer.log(
              "apiv2 new signature=${uriResponse.headers["x-fusion-signature"]}",
              name: _TAG);
          _signature = uriResponse.headers["x-fusion-signature"]!;
          sharedPreferences.setString("signature", _signature);
        } else {
          print(
              "$_TAG apiv2 auth failed ${uriResponse.headers} $_signature $_username $_token");
          print(
              "$_TAG apiv2 auth failed statuscode=${uriResponse.statusCode} ${uriResponse.body}");
          print(
              "$_TAG apiv2 auth to hash $_token:$_username:/api/v1$route$urlParams:${requestBody.isEmpty ? requestBody : ""}:$_signature");
        }
        if (retryCount >= 5) {
          developer.log("apiv2 retried $url 5 times", name: _TAG);
          if (onError != null) {
            onError();
          }
        } else {
          await Future.delayed(Duration(seconds: 1), () async {
            developer.log("apiv2 retry future $url", name: _TAG);
            await apiV2Call(method, route, data,
                onError: onError,
                callback: callback,
                retryCount: retryCount + 1);
          });
        }
      } else if (uriResponse?.statusCode != 200) {
        developer.log(
            "apiv2 request failing $method $url ${uriResponse?.statusCode} ${_authToken}",
            name: _TAG);
      } else {
        var jsonResponse = convert.jsonDecode(uriResponse?.body ?? "");
        if (callback != null) callback(jsonResponse);
      }
    } finally {
      client.close();
    }
  }

  apiV2Multipart(String method, String route, Map<String, dynamic> data,
      List<http.MultipartFile> files,
      {required Function callback, int retryCount = 0}) async {
    var client = http.Client();
    try {
      data['username'] = sharedPreferences.getString("username");

      Uri url = Uri.parse('https://$host/api/v2' + route);
      http.MultipartRequest request = new http.MultipartRequest(method, url);
      developer.log("multipartv2 $method $url $data", name: _TAG);
      String _authToken =
          generateMd5("$_token:$_username:/api/v2$route::$_signature");
      request.headers["X-fusion-uid"] = _username;
      request.headers["Authorization"] = "Bearer $_authToken";
      developer.log("multipartv2 u=$_username t=$_authToken", name: _TAG);
      for (String key in data.keys) {
        request.fields[key] = data[key].toString();
      }

      for (http.MultipartFile file in files) {
        request.files.add(file);
      }
      developer.log("multipartv2 headers ${request.headers}", name: _TAG);

      var uriResponse = await request.send();
      String responseBody =
          await uriResponse.stream.transform(utf8.decoder).join();
      if (uriResponse.statusCode == 401 &&
          uriResponse.headers.containsKey("x-fusion-signature")) {
        String serverCurrentSignature =
            uriResponse.headers["x-fusion-signature"] ?? "";
        if (serverCurrentSignature.isNotEmpty &&
            serverCurrentSignature != _signature) {
          developer.log(
            "multipartv2 new signature $serverCurrentSignature}",
            name: _TAG,
          );
          _signature = uriResponse.headers["x-fusion-signature"]!;
          sharedPreferences.setString("signature", _signature);
          if (retryCount >= 5) {
            developer.log("multipartv2 retried $url 5 times", name: _TAG);
          } else {
            await Future.delayed(Duration(seconds: 1), () async {
              developer.log("apiv2 retry future $url", name: _TAG);
              await apiV2Multipart(
                method,
                route,
                data,
                files,
                callback: callback,
                retryCount: retryCount + 1,
              );
            });
          }
        }
        developer.log(
          "multipartv2 authFailed $responseBody ${uriResponse.statusCode}",
          name: _TAG,
        );
      } else if (uriResponse.statusCode != 200) {
        developer.log(
            "multipartv2 failed $method url=$url resp=$responseBody code=${uriResponse.statusCode}",
            name: _TAG);
      } else {
        var jsonResponse = convert.jsonDecode(responseBody);

        callback(jsonResponse);
      }
      developer.log(
          "multipartv2 response $responseBody ${uriResponse.statusCode}",
          name: _TAG);
    } finally {
      client.close();
    }
  }

  myAvatarUrl() {
    return settings!.myAvatar();
  }

  getUid() {
    return _username;
  }

  getExtension() {
    return _extension;
  }

  getDomain() {
    return _domain;
  }

  _postLoginSetup(Function(bool)? callback) async {
    settings.lookupSubscriber();
    coworkers.getCoworkers((data) {});
    await smsDepartments.getDepartments((List<SMSDepartment> lis) {});
    // customFields.fetchFields(); TODO: customFields not used yet
    dids.getDids((p0, p1) => {});
    if (settings.usesV2) {
      contacts.searchV2("", 100, 0, false, (p0, p1, fromPhoneBook) => null);
    } else {
      contacts.search("", 100, 0, (p0, p1, fromPhoneBook) => null);
    }
    conversations.getConversations(
        "-2", 100, 0, (convos, fromServer, departmentId, errorMessage) {});
    unreadMessages.getUnreads((p0, p1) => null);
    if (Platform.isAndroid) {
      phoneContacts.sync();
    } else {
      //TODO: update phone contacts sync for ios
      phoneContacts.syncPhoneContacts();
    }
    contactFields.getFields((List<ContactField> list, bool fromServer) {});
    // setupSocket();
    if (callback != null) {
      callback(true);
    }
    FirebaseMessaging.instance.getToken().then((token) {
      developer.log("got token $token $_pushkitToken", name: _TAG);
      startStreamEvents(token);
      apiV1Call("post", "/clients/device_token",
          {"token": token, "pn_tok": _pushkitToken});
    });

    if (settings!.options.containsKey("enabled_features")) {
      Map<String, dynamic> nsAnsweringRules = await this.nsAnsweringRules();
      apiV2Call("get", "/user", {}, callback: (Map<String, dynamic> data) {
        if (data == null) return;
        settings.setMyUserInfo(
          outboundCallerId: data.containsKey("dynamicDialingDepartment") &&
                  data["dynamicDialingDepartment"] != '' &&
                  settings!.isFeatureEnabled("Dynamic Dialing")
              ? data["dynamicDialingDepartment"]
              : data["outboundCallerId"],
          isDepartment: data["dynamicDialingDepartment"] != '' ?? false,
          cellPhoneNumber: data["cellPhoneNumber"] ?? "",
          useCarrier: data["usesCarrier"] ?? false,
          simParams: nsAnsweringRules['devices'],
          dndIsOn: data["fmOnDnd"] ?? false,
          forceDispoEnabled: data["forceDispositionEnabled"],
        );
      });
    }
  }

  Future<Map<String, dynamic>> nsAnsweringRules() async {
    Map<String, dynamic> ret = {
      "usesCarrier": false,
      "phoneNumber": "",
      "devices": ""
    };
    await nsApiCall("answerrule", "read", {
      "domain": getDomain(),
      "user": getExtension(),
      "uid": getUid()
    }, callback: (Map<String, dynamic> data) {
      List asweringRules =
          data['answering_rule'] != null && data['answering_rule'][0] == null
              ? [data['answering_rule']]
              : data['answering_rule'] ?? [];

      if (asweringRules.isNotEmpty) {
        Map<String, dynamic> activeRule =
            asweringRules.firstWhere((rule) => rule['active'] == "1");
        if (activeRule != null) {
          ret['devices'] = activeRule['sim_parameters'].runtimeType == String
              ? activeRule['sim_parameters']
              : "";
          String simParams = ret['devices'];
          if (simParams.contains('confirm_') &&
              activeRule['sim_control'] == "e" &&
              !simParams.contains("<OwnDevices>")) {
            ret['usesCarrier'] = true;
            List<String> simParamsArray = simParams.split(" ");
            String device = simParamsArray
                    .firstWhere((String e) => e.contains('confirm_')) ??
                "";
            if (device.isNotEmpty) {
              if (device.contains(";delay")) {
                ret['phoneNumber'] = device
                    .substring(0, device.indexOf(';'))
                    .replaceAll("confirm_", "");
              } else {
                ret['phoneNumber'] = device.replaceAll("confirm_", "");
              }
            }
          }
        }
      }
    });
    return ret;
  }

  Future<bool> auth(String username, String password) async {
    bool authenticated = false;
    await apiV2Call(
      "post",
      "/authenticate",
      {"uid": username, "password": password},
      callback: (Map<String, dynamic> response) {
        developer.log("Authed $response", name: _TAG);
        authenticated = response["success"];
        if (authenticated) {
          _username = username;
          // _password = password;
          _domain = _username.split('@')[1];
          _extension = _username.split('@')[0];
          _token = response["token"];
          _signature = response["signature"];
          sharedPreferences.setString("username", username);
          sharedPreferences.setString("token", _token);
          sharedPreferences.setString("signature", _signature);
        }
      },
    );
    return authenticated;
  }

  Future<bool> newLogin(String username, String password) async {
    loggingOut = false;
    bool success = await auth(username, password);
    if (success) {
      loadDomainOptions();
    }
    return success;
  }

  loadDomainOptions() async {
    apiV1Call("post", "/clients/lookup_options", {},
        callback: (Map<String, dynamic> response) {
      if (response.containsKey("access_key")) {
        if (response.containsKey("uses_v2")) {
          sharedPreferences.setBool("v2User", response["uses_v2"]);
          settings.usesV2 = response["uses_v2"];
        }
        settings.setOptions(response);
        _postLoginSetup(null);
      }
    });
  }

  void autoLogin(String username, Function logout) {
    _token = sharedPreferences.getString("token") ?? "";
    _signature = sharedPreferences.getString("signature") ?? "";
    _username = username;
    _domain = _username.split('@')[1];
    _extension = _username.split('@')[0];
    developer.log("autoLogin t=$_token s=$_signature u=$_username", name: _TAG);
    if (_token.isEmpty || _signature.isEmpty) return logout();
    loadDomainOptions();
  }

  // _reconnectSocket() {
  //   if (loggingOut) return;
  //   socketChannel.sink.add(convert.jsonEncode({
  //     "simplii_identification": [_extension, _domain],
  //     "pwd": _password
  //   }));
  // }

  // _sendHeartbeat() {
  //   String beat = randomString(30);
  //   if (loggingOut) return;
  //   _sendToSocket({'heartbeat': beat});
  //   Future.delayed(const Duration(seconds: 15), () {
  //     if (_heartbeats[beat] != null && !_heartbeats[beat]!) {
  //       socketChannel.sink.close();
  //       setupSocket();
  //     }
  //     _heartbeats.remove(beat);
  //     _sendHeartbeat();
  //   });
  // }

  // _sendToSocket(Map<String, dynamic> payload) {
  //   socketChannel.sink.add(convert.jsonEncode(payload));
  // }

  // setupSocket() async {
  //   int messageNum = 0;
  //   final wsUrl = Uri.parse('wss://$host:8443/');
  //   socketChannel = WebSocketChannel.connect(wsUrl);
  //   // websocketStream.addStream(socketChannel.stream);
  //   _wsStream = socketChannel.stream.listen((messageData) async {
  //     developer.log("wsMessage $messageData", name: _TAG);
  //     Map<String, dynamic> message = convert.jsonDecode(messageData);
  //     if (message.containsKey('heartbeat')) {
  //       _heartbeats[message['heartbeat']] = true;
  //     } else if (message.containsKey('sms_received')) {
  //       // Receive incoming message platform data
  //       SMSMessage newMessage = SMSMessage.fromV2(message['message_object']);
  //       if (!received_smses.containsKey(newMessage.id)) {
  //         received_smses[newMessage.id] = true;

  //         List<SMSDepartment> departments = smsDepartments.allDepartments();
  //         List<String> numbers = [];
  //         departments.forEach((element) {
  //           numbers.addAll(element.numbers);
  //         });
  //         if (!numbers.contains(newMessage.from)) {
  //           refreshUnreads();
  //           messages.notifyMessage(newMessage);
  //           messages.storeRecord(newMessage);
  //           unreadMessages.getRecords();
  //         }
  //       } else if (newMessage.messageStatus.isNotEmpty) {
  //         List<SMSMessage> msgs = messages.getRecords();
  //         for (SMSMessage message in msgs) {
  //           if (message.id == newMessage.id) {
  //             message.messageStatus = newMessage.messageStatus;
  //             message.errorMessage = newMessage.errorMessage;
  //             messages.storeRecord(message);
  //           }
  //         }
  //       }
  //     } else if (message.containsKey('new_status')) {
  //       coworkers.storePresence(
  //           message['user'] + '@' + message['domain'].toString().toLowerCase(),
  //           message['new_status'],
  //           message['message']);
  //     }

  //     if (_softphone != null) _softphone!.checkCallIds(message);
  //   }, onDone: () {
  //     print("MDBM FUSIONCONNECTION ws done");
  //   }, onError: (e) {
  //     developer.log("WS ERROR", error: jsonEncode(e), name: _TAG);
  //   });
  //   _reconnectSocket();
  //   _sendHeartbeat();
  // }

  void startStreamEvents(String? FBDeviceToken) {
    Uri url = Uri.parse(
        'https://$host/api/v2/client/streamEvents?username=$_username&deviceToken=$FBDeviceToken');

    String _authToken = generateMd5(
        "$_token:$_username:/api/v2/client/streamEvents?username=$_username&deviceToken=$FBDeviceToken::$_signature");
    Map<String, String> header = {
      "X-fusion-uid": _username,
      "Authorization": "Bearer $_authToken"
    };

    streamEvents.connect(
      "GET",
      url,
      header,
      autoReconnect: true,
      onSuccessCallback: (resp) {
        print("$_TAG streamEvents resp= $resp");
        if (resp != null &&
            resp.stream != null &&
            resp.status == FusionStreamEventConnectionStatus.connected) {
          print("$_TAG adding new stream $resp");
          fusionStreamEvents.addStream(resp.stream!);
        } else {
          print(
              "$_TAG streamEvents StreamEventResp=$resp StreamEventRespStream=${resp?.stream} StreamEventRespConnectionStatus=${resp?.status}");
        }
      },
      onReAuth: (newSignature) {
        if (newSignature != null && newSignature != _signature) {
          _signature = newSignature;
          sharedPreferences.setString("signature", _signature);
          Future.delayed(Duration(seconds: 5), () {
            startStreamEvents(FBDeviceToken);
          });
        }
      },
    );
  }

  void setRefreshUi(Function() callback) {
    _refreshUi = callback;
  }

  // void encryptFusionData(String username, String? password) async {
  //   if (password == null) return;
  //   final String? deviceToken = await FirebaseMessaging.instance.getToken();
  //   if (deviceToken != null) {
  //     final String hash = generateMd5(
  //         username.trim().toLowerCase() + deviceToken + fusionDataHelper);

  //     final enc.Key key = enc.Key.fromUtf8(hash);
  //     // final iv = IV.fromLength(16); (ok in 5.0.1 not in 5.0.3)
  //     final iv = enc.IV.allZerosOfLength(16);
  //     final enc.Encrypter encrypter =
  //         enc.Encrypter(enc.AES(key, padding: null));
  //     final enc.Encrypted encrypted = encrypter.encrypt(password, iv: iv);
  //     final prefs = await SharedPreferences.getInstance();
  //     prefs.setString('fusion-data1', encrypted.base64);
  //   }
  // }

  Future<void> checkInternetConnection() async {
    if (connectivityResult == ConnectivityResult.none) {
      internetAvailable = false;
      return;
    } else {
      final bool isConnected = await InternetConnectionChecker().hasConnection;
      if (isConnected) {
        internetAvailable = true;
      } else {
        internetAvailable = false;
      }
    }
  }

  Future<void> clearCache() async {
    if (Platform.isIOS) {
      MethodChannel ios = MethodChannel('net.fusioncomm.ios/callkit');
      ios.invokeMethod("clearCache");
    } else {
      final cacheDir = await getTemporaryDirectory();
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
      final appDir = await getApplicationSupportDirectory();
      if (appDir.existsSync()) {
        appDir.deleteSync(recursive: true);
      }
    }

    db.delete('phone_contacts').then((value) =>
        print("MyDebugMessage phone_contacts rows effected ${value}"));
    db.delete('contacts').then(
        (value) => print("MyDebugMessage contacts rows effected ${value}"));
    db.delete('phone_contacts').then((value) =>
        print("MyDebugMessage phone_contacts rows effected ${value}"));
    db.delete('sms_conversation').then((value) =>
        print("MyDebugMessage sms_conversation rows effected ${value}"));
    db.delete('sms_message').then(
        (value) => print("MyDebugMessage sms_message rows effected ${value}"));
    db.delete('call_history').then(
        (value) => print("MyDebugMessage call_history rows effected ${value}"));

    await sharedPreferences.clear();
    _clearDataStores();
  }
}
