import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:all_sensors/all_sensors.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_apns/flutter_apns.dart';
// import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fusion_mobile_revamped/src/callpop/call_view.dart';
import 'package:fusion_mobile_revamped/src/callpop/disposition.dart';
import 'package:fusion_mobile_revamped/src/dialpad/dialpad_modal.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/dids.dart';
import 'package:fusion_mobile_revamped/src/models/notification_data.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';

import 'src/backend/fusion_connection.dart';
import 'src/backend/softphone.dart';
import 'src/calls/recent_calls.dart';
import 'src/components/menu.dart';
import 'src/contacts/recent_contacts.dart';
import 'src/login.dart';
import 'src/messages/messages_list.dart';
import 'src/messages/new_message_popup.dart';
import 'src/messages/sms_conversation_view.dart';
import 'src/styles.dart';
import 'src/utils.dart';

final navigatorKey = GlobalKey<NavigatorState>();
Map<String, dynamic> messageData = {};
registerNotifications() {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
// initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('app_icon_background');
  final DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
          onDidReceiveLocalNotification:
              (int i, String? a, String? b, String? s) {});
  // final MacOSInitializationSettings initializationSettingsMacOS =
  //     MacOSInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
  flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );
  return flutterLocalNotificationsPlugin;
}

@pragma('vm:entry-point')
Future<dynamic> backgroundMessageHandler(RemoteMessage message) async {
  print("MDBM bgMessage");
  SharedPreferences pres = await SharedPreferences.getInstance();
  var username = pres.getString('username');
  if (username == null) return;
  print('backgroundMessage: message => ${message.toString()}');
  print('backgroundMessage: message => ${message.data.toString()}');

  var data = message.data;

  if (data.containsKey("remove_fusion_call")) {
    final callUUID = data['uuid'];
    var id = intIdForString(data['remove_fusion_call']);

    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        registerNotifications();

    // MethodChannel callKit = MethodChannel('net.fusioncomm.ios/callkit');
    // callKit.invokeMethod("endCall", [callUUID]);

    // flutterLocalNotificationsPlugin.cancel(id);
  }

  if (data.containsKey("fusion_call") && data['fusion_call'] == "true") {
    // var callerName = data['caller_id'] as String;
    // var callerNumber = data['caller_number'] as String;
    // final callUUID = uuidFromString(data['call_id']);
    // var id = intIdForString(data['call_id']);
    // FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    //     registerNotifications();

    // const AndroidNotificationDetails androidPlatformChannelSpecifics =
    //     AndroidNotificationDetails('fusion', 'Fusion calls',
    //         channelDescription: 'Fusion incoming calls',
    //         importance: Importance.max,
    //         fullScreenIntent: true,
    //         priority: Priority.high,
    //         ticker: 'ticker');
    // const NotificationDetails platformChannelSpecifics =
    //     NotificationDetails(android: androidPlatformChannelSpecifics);

    // flutterLocalNotificationsPlugin.show(
    //     id,
    //     callerName,
    //     callerNumber.formatPhone() + ' incoming phone call',
    //     platformChannelSpecifics,
    //     payload: callUUID.toString());

    // var timer = Timer(Duration(seconds: 40), () {
    //   flutterLocalNotificationsPlugin.cancel(id);
    // });
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(backgroundMessageHandler); // }

  registerNotifications();

  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  /*await SentryFlutter.init(
    (options) {
      options.diagnosticLevel = SentryLevel.error;
      options.dsn =
          'https://62008a087492473a86289c64d827bf87@fusion-sentry.simplii.net/2';
    },
    appRunner: () =>
        runApp(OverlaySupport.global(child: MaterialApp(home: MyApp()))),
  );*/
  runApp(OverlaySupport.global(child: MaterialApp(home: MyApp())));
  // runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  late FusionConnection _fusionConnection;
  late Softphone _softphone;
  RemoteMessage? _launchMessage;
  static final GlobalKey navigationKey = GlobalKey<NavigatorState>();
  MyApp() {
    _fusionConnection = FusionConnection();
    _softphone = Softphone(_fusionConnection);
    _fusionConnection.setSoftphone(_softphone);
  }

  bool _listenerHasBeenSetup = false;

  _setupListener() async {}

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    _softphone.setContext(context);
    if (!_listenerHasBeenSetup) {
      _setupListener();
      _listenerHasBeenSetup = true;
    }

    return MaterialApp(
      builder: (BuildContext context, Widget? child) {
        final double scaleRange =
            MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: scaleRange),
          child: child!,
        );
      },
      title: 'Fusion Revamped',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.grey,
      ),
      home: MyHomePage(
          title: 'Fusion Revamped',
          softphone: _softphone,
          fusionConnection: _fusionConnection),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage(
      {Key? key,
      this.title,
      required this.softphone,
      required this.fusionConnection,
      this.launchMessage})
      : super(key: key);
  final Softphone softphone;
  final FusionConnection fusionConnection;
  final String? title;
  final RemoteMessage? launchMessage;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Softphone get softphone => widget.softphone;

  FusionConnection get fusionConnection => widget.fusionConnection;
  String _sub_login = "";
  String _auth_key = "";
  String _aor = "";
  final phoneNumberController = TextEditingController();
  String? receivedMsg;
  List<Call>? calls;
  Call? activeCall;
  RemoteMessage? _launchMessage;
  bool _isRegistering = false;
  bool _logged_in = false;
  bool _callInProgress = false;
  bool _isProximityListening = false;
  late StreamSubscription<ProximityEvent> _proximitySub;
  bool flutterBackgroundInitialized = false;
  Function? onMessagePosted;
  _logOut() {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.remove('username');
      prefs.setString("sub_login", "");
      prefs.setString("aor", "");
      prefs.setString("auth_key", "");
      prefs.setString('selectedGroupId', "-2");
    });
    Navigator.of(context).popUntil((route) => route.isFirst);
    this.setState(() {
      _isRegistering = false;
      _sub_login = "";
      _aor = "";
      _auth_key = "";
      _callInProgress = false;
      _logged_in = false;
    });
    softphone.unregisterLinphone();
    // if(Platform.isAndroid){
    //   SystemNavigator.pop();
    // }
  }

  @override
  initState() {
    super.initState();

    receivedMsg = "";
    fusionConnection.onLogOut(_logOut);
    softphone.onUpdate(() {
      setState(() {});
    });
    print("MDBM INITSTATE DART MAIN");
    _autoLogin();
    // need to move _setupPermissions away from initState
    // or will have error when dart execute in the background
    // specially phone.request
    _setupPermissions();

    // final connector = createPushConnector();
    // connector.configure(
    //     onLaunch: _onLaunch, onResume: _onResume, onMessage: _onMessage);
    // fusionConnection!.setAPNSConnector(connector);
    _setupFirebase();
    fusionConnection.setRefreshUi(() {
      this.setState(() {});
    });
  }

  Future<void> _setupPermissions() async {
    await Permission.phone.request();
    await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: true,
        provisional: false,
        sound: true);
  }
  // FOR IOS
  // Future<void> _onLaunch(RemoteMessage m) async {
  //   _launchMessage = m;
  // }

  // Future<void> _onResume(RemoteMessage m) async {
  //   softphone.reregister();
  // }

  // Future<void> _onMessage(RemoteMessage m) async {
  //   if(onMessagePosted !=  null){
  //     onMessagePosted!(()=>{});
  //   }
  // }

  checkForInitialMessage({String? username}) async {
    await Firebase.initializeApp();
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage == null && _launchMessage != null) {
      initialMessage = _launchMessage;
      _launchMessage = null;
    }

    // if (initialMessage != null) {
    //   checkForIMNotification(initialMessage.data, username: username);
    // }
  }

  checkForIMNotification(Map<String, dynamic> d, {String? username}) async {
    NotificationData notificationData = NotificationData.fromJson(d);
    String depId = notificationData.departmentId ?? DepartmentIds.AllMessages;

    if (notificationData.toNumber.isNotEmpty && notificationData.isGroup) {
      List<SMSDepartment> deps = fusionConnection.smsDepartments.allDepartments();
      if (deps.isEmpty) {
        await fusionConnection.smsDepartments.getDepartments((p0) => deps = p0);
      }
      SMSDepartment? dep = deps.where((element) => element.id == depId).firstOrNull;
      String numberUsed = "";

      List<String> depNumbers = dep?.numbers ?? [];
      List<Contact> convoContacts = [];

      for (String num in notificationData.numbers) {
        for (NotificationMember member in notificationData.members) {
          if (depNumbers.contains(num)) {
            numberUsed = num;
          }
          if (num == numberUsed) {
            continue;
          }
          if (num == member.number) {
            convoContacts.add(
              Contact.build(name: member.name, pictures: [{"url" : member.avatar}])
            );
          } else {
            convoContacts.add(
              Contact.fake(num)
            );
          }
        }
      }
      print("MDBM res here group");
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            SMSConversation displayingConvo = SMSConversation.build(
                contacts: convoContacts,
                conversationId: int.parse(notificationData.toNumber),
                crmContacts: [],
                selectedDepartmentId: depId,
                hash: notificationData.numbers.join(':'),
                isGroup: notificationData.isGroup,
                myNumber: numberUsed,
                number: notificationData.toNumber);
            return SMSConversationView(
                fusionConnection: fusionConnection,
                softphone: softphone,
                smsConversation: displayingConvo,
                deleteConvo: null,
                setOnMessagePosted: null,
                changeConvo: (SMSConversation updateConvo) {
                  setState(
                    () {
                      displayingConvo = updateConvo;
                    },
                  );
                });
          },
        ),
      );
    } else if (notificationData.toNumber.isNotEmpty && !notificationData.isGroup) {
      fusionConnection.contacts.search(notificationData.fromNumber, 10, 0,
          (contacts, contactsFromServer, contactsFromPhonebook) {
        if (contactsFromServer || contactsFromPhonebook) {
          fusionConnection.integratedContacts.search(notificationData.fromNumber, 10, 0,
              (crmContacts, fromServer, hasMore) {
            if (fromServer || contactsFromPhonebook) {
              if(!fusionConnection.settings.usesV2){
                contacts.addAll(crmContacts);
              }
              fusionConnection.messages.checkExistingConversation(
                depId,
                notificationData.toNumber,
                [notificationData.fromNumber],
                contacts
              ).then((convo) {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => StatefulBuilder(
                    builder: (BuildContext context,StateSetter setState) {
                      SMSConversation displayingConvo = convo;
                      return SMSConversationView(
                          fusionConnection: fusionConnection, 
                          softphone: softphone, 
                          smsConversation: displayingConvo, 
                          deleteConvo: null,//deleteConvo
                          setOnMessagePosted: null,//onMessagePosted
                          changeConvo: (SMSConversation updateConvo){
                            setState(() {
                              displayingConvo = updateConvo;
                            },);
                          }
                      );
                    },
                  ),
                );
              },);
            }
          });
        }
      });
    }
  }

  // _setupFirebase() {
  //   FirebaseMessaging.onMessage.listen((event) {
  //     print("fbmessage");print(event.data);
  //     event.data;
  //     if (Platform.isIOS) {
  //       if (event.data.containsKey("remove_fusion_call")) {
  //         softphone.stopRinging(event.data["uuid"]);
  //       }
  //     }

  //     // setState(() {}); this cause memory leak
  //   });

  //   FirebaseMessaging.onMessageOpenedApp.listen((event) {
  //     checkForIMNotification(event.data);
  //   });
  // }

  registerAndroidForgroundNotification() {
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon_background');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse: _notificationResponse);
    return flutterLocalNotificationsPlugin;
  }

  void _notificationResponse(NotificationResponse response) {
    if (messageData.isNotEmpty) {
      checkForIMNotification(messageData);
    }
  }

  Future<void> _setupFirebase() async {
    // Get any messages which caused the application to open from
    // a terminated state.
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        checkForIMNotification(message.data);
      }
    });

    // handle any interaction when the app is in the background as stream
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      checkForIMNotification(message.data);
    });

    // handle any interaction when the app is in the forground as stream
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;
      if (notification != null && android != null) {
        _handleForgroundMessage(message);
      }
    });
  }

  void _handleForgroundMessage(RemoteMessage message) {
    if (message.notification != null) {
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          registerAndroidForgroundNotification();
      if (message.data.containsKey('remove_fusion_call')) {
        var id = intIdForString(message.data['remove_fusion_call']);
        flutterLocalNotificationsPlugin.cancel(id);
      } else {
        if (Platform.isIOS) return;
        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'fusion1',
          'Fusion chats',
          channelDescription: 'Fusion incoming messages',
          importance: Importance.max,
          icon: "@mipmap/app_icon",
        );

        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);
        flutterLocalNotificationsPlugin.show(
          Random().nextInt(1000),
          message.data['title'],
          message.data['from_number'] + " says: " + message.data['body'],
          platformChannelSpecifics,
        );
        messageData = message.data;
      }
    }
  }

  _autoLogin() {
    SharedPreferences.getInstance().then((SharedPreferences prefs) async {
      String? username = prefs.getString("username");
      if (username != null) {
        String domain = username.split('@')[1];
        String sub_login = prefs.getString("sub_login") ?? "";
        String aor = prefs.getString("aor") ?? "";
        String auth_key = prefs.getString("auth_key") ?? "";

        if (auth_key != null && auth_key != "") {
          setState(() {
            _sub_login = sub_login;
            _auth_key = auth_key;
            _aor = aor;
            _logged_in = true;
            _isRegistering = true;
          });
          softphone.register(sub_login, auth_key, aor.replaceAll('sip:', ''));
          await fusionConnection.autoLogin(username, domain);
          softphone.onUnregister(() {
            fusionConnection.nsApiCall('device', 'read', {
              'domain': fusionConnection.getDomain(),
              'device':
                  'sip:${fusionConnection.getExtension()}fm@${fusionConnection.getDomain()}',
              'user': fusionConnection.getExtension()
            }, callback: (Map<String, dynamic> response) {
              print("deviceread");
              print(response);
              if (!response.containsKey('device')) {
                fusionConnection.logOut();
              }
              Map<String, dynamic> device = response['device'];
              _sub_login = device['sub_login'];
              _auth_key = device['authentication_key'];
              _aor = device['aor'];

              SharedPreferences.getInstance().then((SharedPreferences prefs) {
                prefs.setString("sub_login", _sub_login);
                prefs.setString("auth_key", _auth_key);
                prefs.setString("aor", _aor);
              });

              softphone.register(
                  device['sub_login'],
                  device['authentication_key'],
                  device['aor'].replaceAll('sip:', ''));
            });
          });
          checkForInitialMessage(username: username);
        } else {}
      }
    });
  }

  // void initBackgroundExec() async {
  //   final androidConfig = FlutterBackgroundAndroidConfig(
  //     enableWifiLock: true,
  //     notificationTitle: "Fusion Mobile",
  //     notificationText: "Active call with Fusion Mobile.",
  //     notificationImportance: AndroidNotificationImportance.Default,
  //     notificationIcon: AndroidResource(
  //         name: 'app_icon',
  //         defType: 'drawable'), // Default is ic_launcher from folder mipmap
  //   );
  //   if (!flutterBackgroundInitialized) {
  //     bool success =
  //         await FlutterBackground.initialize(androidConfig: androidConfig);
  //     setState(() {
  //       flutterBackgroundInitialized = success;
  //     });
  //   }
  // }

  Future<void> _register() async {
    if (Platform.isAndroid) {
      // initBackgroundExec();
    }
    if (_isRegistering) {
      return;
    } else if (_sub_login != "") {
      softphone.register(_sub_login, _auth_key, _aor.replaceAll('sip:', ''));
    } else {
      fusionConnection.nsApiCall('device', 'read', {
        'domain': fusionConnection.getDomain(),
        'device':
            'sip:${fusionConnection.getExtension()}fm@${fusionConnection.getDomain()}',
        'user': fusionConnection.getExtension()
      }, callback: (Map<String, dynamic> response) {
        print("deviceread");
        print(response);
        if (!response.containsKey('device')) {
          toast(
              "You don't seem to have a fusion mobile device registered, please contact support.",
              duration: Toast.LENGTH_LONG);
          fusionConnection.logOut();
        }
        Map<String, dynamic> device = response['device'];
        _sub_login = device['sub_login'];
        _auth_key = device['authentication_key'];
        _aor = device['aor'];

        SharedPreferences.getInstance().then((SharedPreferences prefs) {
          prefs.setString("sub_login", _sub_login);
          prefs.setString("auth_key", _auth_key);
          prefs.setString("aor", _aor);
        });

        softphone.register(device['sub_login'], device['authentication_key'],
            device['aor'].replaceAll('sip:', ''));
      });
    }
  }

  int _currentIndex = 0;

  void onTabTapped(int index) {
    this.setState(() {
      _currentIndex = index;
    });
  }

  void _openDialPad() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => DialPadModal(fusionConnection, softphone));
  }

  void _openCallView() {
    this.setState(() {
      _callInProgress = !_callInProgress;
    });
  }

  _openNewMessage() {
    showModalBottomSheet(
        routeSettings: RouteSettings(name: 'newMessagePopup'),
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) =>
            NewMessagePopup(fusionConnection, softphone, onMessagePosted));
  }

  void _loginSuccess(String? username, String? password) {
    this.setState(() {
      _logged_in = true;
    });
    _register();
    checkForInitialMessage();
  }

  _getFloatingButton() {
    if (_currentIndex == 0) {
      return FloatingActionButton(
        onPressed: _openDialPad,
        backgroundColor: crimsonLight,
        foregroundColor: Colors.white,
        child: Icon(Icons.dialpad),
      );
    } else if (_currentIndex == 2) {
      bool _canSendMessage = false;
      List<SMSDepartment> deps = fusionConnection.smsDepartments.getRecords();
      for (var dep in deps) {
        if (dep.numbers.isNotEmpty) {
          _canSendMessage = true;
          break;
        }
      }
      return FloatingActionButton(
        backgroundColor:
            _canSendMessage ? crimsonLight : crimsonLight.withOpacity(0.5),
        foregroundColor: Colors.white,
        onPressed: _canSendMessage ? _openNewMessage : null,
        child: Icon(Icons.add),
      );
    } else {
      return null;
    }
  }

  _getTabWidget() {
    return (_currentIndex == 0
        ? RecentCallsTab(fusionConnection, softphone)
        : (_currentIndex == 1
            ? RecentContactsTab(fusionConnection, softphone)
            : MessagesTab(fusionConnection, softphone, (Function func) {
                onMessagePosted = func;
              }, () {
                onMessagePosted = null;
              })));
  }

  @override
  Widget build(BuildContext context) {
    // if (softphone.activeCall != null &&
    //     softphone.isConnected(softphone.activeCall!) != null &&
    //     !FlutterBackground.isBackgroundExecutionEnabled &&
    //     Platform.isAndroid) {
    //   if (!flutterBackgroundInitialized) {
    //     // initBackgroundExec();
    //   }
    //   // FlutterBackground.enableBackgroundExecution()
    //   //     .then((value) => print("enablebgexecutionvalue" + value.toString()));
    // } else if (FlutterBackground.isBackgroundExecutionEnabled &&
    //     Platform.isAndroid &&
    //     softphone.activeCall == null) {
    //   FlutterBackground.disableBackgroundExecution()
    //       .then((value) => print("disablebgexecutionvalue" + value.toString()));
    // }
    if (softphone.activeCall != null &&
        softphone.isConnected(softphone.activeCall!) != null &&
        !softphone.getHoldState(softphone.activeCall) &&
        !softphone.isSpeakerEnabled() &&
        !_isProximityListening) {
      _isProximityListening = true;
      _proximitySub = proximityEvents!.listen((ProximityEvent event) {
        setState(() {});
      });
    } else if (_isProximityListening &&
        (softphone.activeCall == null ||
            softphone.getHoldState(softphone.activeCall) ||
            softphone.isSpeakerEnabled())) {
      _isProximityListening = false;
      _proximitySub.cancel();
    }

    if (!_logged_in) {
      return Container(
          decoration: BoxDecoration(
              image: DecorationImage(
                  image: AssetImage("assets/fill.jpg"), fit: BoxFit.cover)),
          child: Scaffold(
              backgroundColor: bgBlend,
              body:
                  SafeArea(child: LoginView(_loginSuccess, fusionConnection))));
    }

    if (softphone.activeCall != null) {
      return CallView(fusionConnection, softphone, closeView: _openCallView);
    }

    if (softphone.endedCalls.isNotEmpty) {
      for (var call in softphone.endedCalls) {
        return DispositionView(
          terminatedCall: call,
          fusionConnection: fusionConnection,
          softphone: softphone,
          onDone: () => setState(() {}),
        );
      }
    }
    return Container(
        decoration: BoxDecoration(
            image: DecorationImage(
                image: AssetImage("assets/fill.jpg"), fit: BoxFit.cover)),
        child: Stack(
          children: [
            Container(color: bgBlend),
            SafeArea(
                child: Stack(children: [
              Scaffold(
                  drawer: Menu(fusionConnection, softphone),
                  backgroundColor: Colors.transparent,
                  body: _getTabWidget(),
                  floatingActionButton: _getFloatingButton(),
                  bottomNavigationBar: Container(
                      height: Platform.isAndroid ? 60 : 60.0,
                      margin: EdgeInsets.only(top: 0, left: 16, right: 16),
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(
                                child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                        color: _currentIndex == 0
                                            ? crimsonLight
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(2),
                                          bottomRight: Radius.circular(2),
                                        )))),
                            Expanded(
                                child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                        color: _currentIndex == 1
                                            ? crimsonLight
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(2),
                                          bottomRight: Radius.circular(2),
                                        )))),
                            Expanded(
                                child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                        color: _currentIndex == 2
                                            ? crimsonLight
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.only(
                                          bottomLeft: Radius.circular(2),
                                          bottomRight: Radius.circular(2),
                                        )))),
                          ]),
                          BottomNavigationBar(
                            elevation: 0,
                            backgroundColor: Colors.transparent,
                            selectedItemColor: Colors.white,
                            unselectedItemColor: smoke,
                            onTap: onTabTapped,
                            currentIndex: _currentIndex,
                            iconSize: 20,
                            selectedLabelStyle: TextStyle(
                                height: 1.8,
                                fontSize: 10,
                                fontWeight: FontWeight.w800),
                            unselectedLabelStyle: TextStyle(
                                height: 1.8,
                                fontSize: 10,
                                fontWeight: FontWeight.w800),
                            items: [
                              BottomNavigationBarItem(
                                icon: Image.asset(
                                    "assets/icons/phone_btmbar.png",
                                    width: 18,
                                    height: 18),
                                activeIcon: Image.asset(
                                    "assets/icons/phone_filled_white.png",
                                    width: 18,
                                    height: 18),
                                label: "Calls",
                              ),
                              BottomNavigationBarItem(
                                icon: Opacity(
                                    child: Image.asset(
                                        "assets/icons/people.png",
                                        width: 18,
                                        height: 18),
                                    opacity: 0.5),
                                activeIcon: Image.asset(
                                    "assets/icons/people.png",
                                    width: 18,
                                    height: 18),
                                label: "People",
                              ),
                              BottomNavigationBarItem(
                                  icon: fusionConnection.unreadMessages
                                          .hasUnread()
                                      ? Image.asset(
                                          "assets/icons/message_btmbar_notif.png",
                                          width: 18,
                                          height: 18)
                                      : Image.asset(
                                          "assets/icons/message_btmbar.png",
                                          width: 18,
                                          height: 18),
                                  activeIcon: fusionConnection.unreadMessages
                                          .hasUnread()
                                      ? Image.asset(
                                          "assets/icons/message_filled_white_notif.png",
                                          width: 18,
                                          height: 18)
                                      : Image.asset(
                                          "assets/icons/message_filled_white.png",
                                          width: 18,
                                          height: 18),
                                  label: 'Messages')
                            ],
                          )
                        ],
                      ))),
            ]))
          ],
        ));
  }
}
