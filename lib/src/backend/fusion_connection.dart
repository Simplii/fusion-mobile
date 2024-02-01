import 'dart:async';
import 'dart:convert' as convert;
import 'dart:convert';
import 'dart:core';
import 'dart:core';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_apns/src/connector.dart';
import 'package:fusion_mobile_revamped/src/models/contact_fields.dart';
import 'package:fusion_mobile_revamped/src/models/dids.dart';
import 'package:fusion_mobile_revamped/src/models/park_lines.dart';
import 'package:fusion_mobile_revamped/src/models/phone_contact.dart';
import 'package:fusion_mobile_revamped/src/models/quick_response.dart';
import 'package:fusion_mobile_revamped/src/models/timeline_items.dart';
import 'package:fusion_mobile_revamped/src/models/unreads.dart';
import 'package:fusion_mobile_revamped/src/models/voicemails.dart';
import 'package:fusion_mobile_revamped/src/styles.dart';
import 'package:http/http.dart';
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
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:websocket_manager/websocket_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../utils.dart';
import 'softphone.dart';
import 'package:encrypt/encrypt.dart' as enc;

class FusionConnection {
  String _extension = '';
  String _username = '';
  String _password = '';
  String _domain = '';
  Map<String, bool> _heartbeats = {};
  late CrmContactsStore crmContacts;
  late ContactsStore contacts;
  late PhoneContactsStore phoneContacts;
  late CallpopInfoStore callpopInfos;
  // WebsocketManager _socket;
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
  late Database db;
  // PushConnector? _connector;
  String? _pushkitToken;
  Softphone? _softphone;
  PersistCookieJar? _cookies;
  Function _onLogOut = () {};
  Function _refreshUi = () {};
  Map<String, bool> received_smses = {};
  Connectivity connectivity = Connectivity();
  ConnectivityResult connectivityResult = ConnectivityResult.none;
  bool internetAvailable = true;
  String serverRoot = "http://fusioncom.co";
  String mediaServer = "https://fusion-media.sfo2.digitaloceanspaces.com";
  String defaultAvatar = "https://fusioncom.co/img/defaultuser.png";
  static const MethodChannel contactsChannel =
      MethodChannel('net.fusioncomm.ios/contacts');

  FusionConnection() {
    _getCookies();
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

  refreshUnreads() {
    unreadMessages
        .getUnreads((List<DepartmentUnreadRecord> messages, bool fromServer) {
      _refreshUi();
    });
  }

  bool isLoginFinished() {
    return _username != "" && _password != "";
  }

  _getCookies({Function? callback}) async {
    getApplicationDocumentsDirectory().then((directory) {
      _cookies = PersistCookieJar(
          persistSession: true,
          ignoreExpires: true,
          storage: FileStorage(directory.path));

      if (callback != null) {
        callback();
      }
    }).onError((dynamic er, err) {
      print("cookie error");
      print(er);
      callback!();
    });
  }

  setSoftphone(Softphone? softphone) {
    _softphone = softphone;
  }

  final channel = WebSocketChannel.connect(
    Uri.parse('wss://fusioncom.co:8443'),
  );

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
    timelineItems.clearRecords();
    parkLines.clearRecords();
    voicemails.clearRecords();
    dids.clearRecords();
    unreadMessages.clearRecords();
    quickResponses.clearRecords();
    phoneContacts.clearRecords();
  }

  logOut() {
    FirebaseMessaging.instance.getToken().then((token) {
      if (_pushkitToken != null) {
        apiV1Call("delete", "/clients/device_token", {"token": _pushkitToken});
      }
      apiV1Call("delete", "/clients/device_token",
          {"token": token, "pn_tok": _pushkitToken}, callback: (data) {
        apiV1Call("get", "/log_out", {}, callback: (data) {
          SharedPreferences.getInstance().then((SharedPreferences prefs) {
            prefs.setString("sub_login", "");
            prefs.setString("auth_key", "");
            prefs.setString("aor", "");
          });
          _username = '';
          _password = '';
          try {
            if (_softphone != null) {
              _softphone!.stopInbound();
              _softphone!.close();
              setSoftphone(null);
            }
            _onLogOut();
          } catch (e) {}
          _cookies!.deleteAll();
          _clearDataStores();
        });
      });
    });
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
          broadcastConvoId int
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
          phoneContact BLOB
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
        this.db = db;
      }).catchError((error) {});
    });
  }

  _getUsername() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString("username");
  }

  _saveCookie(Response response) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (response.headers.containsKey('set-cookie')) {
      List<String> cookieStrings =
          response.headers['set-cookie']!.split("HttpOnly,");
      for (String cookieString in cookieStrings) {
        Cookie cookie = Cookie.fromSetCookieValue(cookieString);
        if (cookie.name == "fusionsession") {
          prefs.setString("fusionCookie", cookie.value.toString());
        } else if (cookie.name == "sec_session_id") {
          prefs.setString("secSessionId", cookie.value.toString());
        }

        _cookies?.saveFromResponse(response.request!.url, [cookie]);
      }
    }
  }

  Future<Map<String, String>> _cookieHeaders(url) async {
    Completer<Map<String, String>> c = new Completer<Map<String, String>>();
    var runIt = () async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String fusionCookie = prefs.getString("fusionCookie") ?? "";
      String secSessionId = prefs.getString("secSessionId") ?? "";
      String cookiesHeader = "";
      Map<String, String> headers = {};
      if (fusionCookie.isNotEmpty) {
        cookiesHeader =
            "fusionsession=$fusionCookie; sec_session_id=$secSessionId;";
        headers['cookie'] = cookiesHeader;
        return c.complete(headers);
      }

      List<Cookie> cookies = await _cookies!.loadForRequest(url);

      for (Cookie c in cookies) {
        cookiesHeader += c.name + "=" + c.value + "; ";
      }
      headers['cookie'] = cookiesHeader;
      c.complete(headers);
    };

    if (_cookies == null) {
      _getCookies(callback: runIt);
    } else {
      runIt();
    }
    return c.future;
  }

  nsApiCall(String object, String action, Map<String, dynamic> data,
      {required Function callback}) async {
    var client = http.Client();
    try {
      data['action'] = action;
      data['object'] = object;
      data['username'] = await _getUsername();

      Uri url = Uri.parse(
          'https://fusioncom.co/api/v1/clients/api_request?username=' +
              data['username']);
      Map<String, String> headers = await _cookieHeaders(url);
      String body = convert.jsonEncode(data);
      headers["Content-Type"] = "application/json";

      var uriResponse = await client.post(url, headers: headers, body: body);
      _saveCookie(uriResponse);
      Map<String, dynamic>? jsonResponse = {};
      try {
        jsonResponse =
            convert.jsonDecode(uriResponse.body) as Map<String, dynamic>?;
      } catch (e) {}
      print(url);
      print(jsonResponse);
      client.close();
      callback(jsonResponse);
    } finally {
      client.close();
    }
  }

  apiV1Call(String method, String route, Map<String, dynamic> data,
      {Function? callback, Function? onError, int retryCount = 0}) async {
    var client = http.Client();

    try {
      data['username'] = await _getUsername();

      Function fn = {
        'post': client.post,
        'get': client.get,
        'patch': client.patch,
        'put': client.put,
        'delete': client.delete
      }[method.toLowerCase()]!;

      Map<Symbol, dynamic> args = {};
      String urlParams = '?';
      if (method.toLowerCase() == 'get') {
        for (String key in data.keys) {
          RegExp reg = RegExp((r'[^\x20-\x7E]'));
          urlParams += key +
              "=" +
              Uri.encodeQueryComponent(
                  data[key].toString().trim().replaceAll(reg, '')) +
              '&';
        }
      }
      Uri url = Uri.parse('https://fusioncom.co/api/v1' + route + urlParams);
      Map<String, String> headers = await _cookieHeaders(url);
      if (method.toLowerCase() != 'get') {
        args[#body] = convert.jsonEncode(data);
        headers["Content-Type"] = "application/json";
      }

      args[#headers] = headers;
      Response? uriResponse;
      try {
        uriResponse = await Function.apply(fn, [url], args);
        if (uriResponse!.body != '{"error":"invalid_login"}') {
          _saveCookie(uriResponse);
        }
      } catch (e) {
        toast("${e}");
        print("MyDebugMessage apiCallV1 error ${e}");
      }
      print('url $url');
      print(uriResponse!.body);
      print(data);
      print(urlParams);

      if (uriResponse.body == '{"error":"invalid_login"}') {
        print("MyDebugMessage apiv1 ${uriResponse.body} ${url} ${data}");
        if (onError != null) {
          if (retryCount >= 5) {
            onError();
          } else {
            Future.delayed(Duration(seconds: 1), () {
              print("MyDebugMessage retry future");
              apiV1Call(method, route, data,
                  onError: onError,
                  callback: callback,
                  retryCount: retryCount + 1);
            });
          }
        }
      } else {
        var jsonResponse = convert.jsonDecode(uriResponse.body);
        client.close();
        if (callback != null) callback(jsonResponse);
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

      data['username'] = await _getUsername();
      Map<Symbol, dynamic> args = {};
      String urlParams = '?';

      if (method.toLowerCase() == 'get') {
        for (String key in data.keys) {
          urlParams +=
              key + "=" + Uri.encodeQueryComponent(data[key].toString()) + '&';
        }
      }
      Uri url = Uri.parse('https://fusioncom.co/api/v2' + route + urlParams);
      Map<String, String> headers = await _cookieHeaders(url);

      if (method.toLowerCase() != 'get') {
        args[#body] = convert.jsonEncode(data);
        headers["Content-Type"] = "application/json";
      }

      args[#headers] = headers;
      Response? uriResponse;
      try {
        uriResponse = await Function.apply(fn, [url], args);
        if (uriResponse!.body != '{"error":"invalid_login"}') {
          _saveCookie(uriResponse);
        }
      } catch (e) {
        toast("${e}");
        print("MyDebugMessage apiCallV2 error ${e}");
      }

      print("apirequest");
      print(url);
      print(urlParams);
      print(data);
      print(uriResponse!.body);
      if (uriResponse.body == '{"error":"invalid_login"}') {
        if (onError != null) {
          if (retryCount >= 5) {
            onError();
          } else {
            Future.delayed(Duration(seconds: 1), () {
              print("MyDebugMessage retry v2 future");
              apiV2Call(method, route, data,
                  onError: onError,
                  callback: callback,
                  retryCount: retryCount + 1);
            });
          }
        }
      }
      var jsonResponse = convert.jsonDecode(uriResponse.body);
      if (callback != null) callback(jsonResponse);
    } finally {
      client.close();
    }
  }

  apiV2Multipart(String method, String route, Map<String, dynamic> data,
      List<http.MultipartFile> files,
      {required Function callback}) async {
    var client = http.Client();
    try {
      data['username'] = await _getUsername();

      Uri url = Uri.parse('https://fusioncom.co/api/v2' + route);
      http.MultipartRequest request = new http.MultipartRequest(method, url);
      (await _cookieHeaders(url)).forEach((k, v) => request.headers[k] = v);

      for (String key in data.keys) {
        request.fields[key] = data[key].toString();
      }

      for (http.MultipartFile file in files) {
        request.files.add(file);
      }

      var uriResponse = await request.send();
      String responseBody =
          await uriResponse.stream.transform(utf8.decoder).join();
      print(url);
      print(responseBody);
      var jsonResponse = convert.jsonDecode(responseBody);

      callback(jsonResponse);
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

  Creds getCreds() {
    return Creds(_username, _password);
  }

  _postLoginSetup(Function(bool) callback) async {
    _getCookies();
    settings!.lookupSubscriber();
    coworkers.getCoworkers((data) {});
    await smsDepartments.getDepartments((List<SMSDepartment> lis) {});
    dids.getDids((p0, p1) => {});
    contacts.searchV2("", 100, 0, false, (p0, p1, fromPhoneBook) => null);
    contacts.search("", 100, 0, (p0, p1, fromPhoneBook) => null);
    conversations.getConversations(
        "-2", 100, 0, (convos, fromServer, departmentId) {});
    refreshUnreads();
    phoneContacts.syncPhoneContacts();
    contactFields.getFields((List<ContactField> list, bool fromServer) {});
    setupSocket();
    if (callback != null) {
      callback(true);
    }
    FirebaseMessaging.instance.getToken().then((token) {
      print("got token");
      print(token);
      print(_pushkitToken);
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

  login(String username, String? password, Function(bool) callback) {
    if (password == null) return;
    apiV1Call(
        "post",
        "/clients/lookup_options",
        password != null
            ? {"username": username, "password": password}
            : {"username": username}, onError: () {
      callback(false);
    }, callback: (Map<String, dynamic> response) {
      if (response.containsKey("access_key")) {
        _username = username.split('@')[0] + '@' + response['domain'];

        SharedPreferences.getInstance().then((SharedPreferences prefs) {
          prefs.setString("username", _username);
          if (response.containsKey("uses_v2")) {
            prefs.setBool("v2User", response["uses_v2"]);
          }
        });
        this.encryptFusionData(username, password);
        _username = _username;
        _password = password;
        _domain = _username.split('@')[1];
        _extension = _username.split('@')[0];
        settings.setOptions(response);
        _postLoginSetup(callback);
      } else {
        callback(false);
      }
    });
  }

  _reconnectSocket() {
    socketChannel.sink.add(convert.jsonEncode({
      "simplii_identification": [_extension, _domain],
      "pwd": _password
    }));
  }

  // _reconnectSocket() {
  //   _socket.connect().then((val) {
  //     _socket.send(convert.jsonEncode({
  //       "simplii_identification": [_extension, _domain],
  //       "pwd": _password
  //     }));
  //   });
  // }

  _sendHeartbeat() {
    String beat = randomString(30);
    _sendToSocket({'heartbeat': beat});
    Future.delayed(const Duration(seconds: 15), () {
      if (_heartbeats[beat] != null && !_heartbeats[beat]!) {
        socketChannel.sink.close();
        setupSocket();
      }
      _heartbeats.remove(beat);
      _sendHeartbeat();
    });
  }

  _sendToSocket(Map<String, dynamic> payload) {
    socketChannel.sink.add(convert.jsonEncode(payload));
  }

  setupSocket() {
    int messageNum = 0;
    final wsUrl = Uri.parse('wss://fusioncom.co:8443/');
    socketChannel = WebSocketChannel.connect(wsUrl);
    socketChannel.stream.listen((messageData) async {
      Map<String, dynamic> message = convert.jsonDecode(messageData);
      if (message.containsKey('heartbeat')) {
        _heartbeats[message['heartbeat']] = true;
      } else if (message.containsKey('sms_received')) {
        // Receive incoming message platform data
        SMSMessage newMessage = SMSMessage.fromV2(message['message_object']);
        if (!received_smses.containsKey(newMessage.id)) {
          received_smses[newMessage.id] = true;

          List<SMSDepartment> departments = smsDepartments.allDepartments();
          List<String> numbers = [];
          departments.forEach((element) {
            numbers.addAll(element.numbers);
          });
          if (!numbers.contains(newMessage.from)) {
            refreshUnreads();
            await messages.notifyMessage(newMessage);
            messages.storeRecord(newMessage);
            unreadMessages.getRecords();
          }
        } else if (newMessage.messageStatus.isNotEmpty) {
          List<SMSMessage> msgs = messages.getRecords();
          for (SMSMessage message in msgs) {
            if (message.id == newMessage.id) {
              message.messageStatus = newMessage.messageStatus;
              messages.storeRecord(message);
            }
          }
        }
      } else if (message.containsKey('new_status')) {
        coworkers.storePresence(
            message['user'] + '@' + message['domain'].toString().toLowerCase(),
            message['new_status'],
            message['message']);
      }

      if (_softphone != null) _softphone!.checkCallIds(message);
    });
    _reconnectSocket();
    _sendHeartbeat();
  }

  // void setAPNSConnector(PushConnector connector) {
  //   _connector = connector;
  // }

  Future<void> auth() async {
    final prefs = await SharedPreferences.getInstance();
    String? user = await prefs.getString("username");
    String? _pass = await prefs.getString('fusion-data1');
    settings.usesV2 = prefs.getBool("v2User") ?? false;
    if (_pass != null && _pass.isNotEmpty && user != null) {
      if (Platform.isIOS) {
        await FirebaseMessaging.instance.getAPNSToken();
      }
      final String deviceToken =
          await FirebaseMessaging.instance.getToken() ?? "";
      final String hash = generateMd5(
          user.trim().toLowerCase() + deviceToken + fusionDataHelper);
      final enc.Key key = enc.Key.fromUtf8(hash);
      // final enc.IV iv = enc.IV.fromLength(16); (ok in 5.0.1 not in 5.0.3)
      final enc.IV iv = enc.IV.allZerosOfLength(16);
      final enc.Encrypter encrypter =
          enc.Encrypter(enc.AES(key, padding: null));
      _pass = encrypter.decrypt(enc.Encrypted.fromBase64(_pass), iv: iv);

      _username = user.trim();
      _password = _pass;
      try {
        Response res = await http.post(
            Uri.parse('https://fusioncom.co/api/v2/user/auth'),
            body: {"username": _username, "password": _password});
        // print('url https://fusioncom.co/api/v2/user/auth');
        // print(res.headers['set-cookie']);
        Map<String, dynamic> body = jsonDecode(res.body);
        if (body.containsKey("success")) {
          _saveCookie(res);
        }
      } catch (e) {}
    }
  }

  Future<void> autoLogin(String username, String domain) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await auth();

    await apiV1Call("get", "/clients/lookup_options", {}, onError: () {
      toast(
          "Sorry we weren't able to get your login credentials, try logging in again");
    }, callback: (Map<String, dynamic> response) {
      if (response.containsKey("access_key")) {
        _username = username.split('@')[0] + '@' + response['domain'];
        _domain = response['domain'];
        _extension = _username.split('@')[0];
        if (response.containsKey("uses_v2")) {
          prefs.setBool("v2User", response["uses_v2"]);
        }
        settings.setOptions(response);
        _postLoginSetup((bool success) {});
      } else {
        if (kDebugMode) {
          print("MyDebugMessage lookup_options resp ${response}");
        }
        logOut();
      }
    });
  }

  void setRefreshUi(Function() callback) {
    _refreshUi = callback;
  }

  void encryptFusionData(String username, String? password) async {
    if (password == null) return;
    final String? deviceToken = await FirebaseMessaging.instance.getToken();
    if (deviceToken != null) {
      final String hash = generateMd5(
          username.trim().toLowerCase() + deviceToken + fusionDataHelper);

      final enc.Key key = enc.Key.fromUtf8(hash);
      // final iv = IV.fromLength(16); (ok in 5.0.1 not in 5.0.3)
      final iv = enc.IV.allZerosOfLength(16);
      final enc.Encrypter encrypter =
          enc.Encrypter(enc.AES(key, padding: null));
      final enc.Encrypted encrypted = encrypter.encrypt(password, iv: iv);
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('fusion-data1', encrypted.base64);
    }
  }

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

    SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    _clearDataStores();
  }
}

class Creds {
  String username;
  String pass;
  Creds(this.username, this.pass);
}
