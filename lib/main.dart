import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

// import 'package:all_sensors/all_sensors.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_apns/flutter_apns.dart';
// import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fusion_mobile_revamped/src/callpop/call_view.dart';
import 'package:fusion_mobile_revamped/src/callpop/disposition.dart';
import 'package:fusion_mobile_revamped/src/chats/chats.dart';
import 'package:fusion_mobile_revamped/src/chats/conversationView.dart';
import 'package:fusion_mobile_revamped/src/chats/newConversationView.dart';
import 'package:fusion_mobile_revamped/src/chats/viewModels/chatsVM.dart';
import 'package:fusion_mobile_revamped/src/components/fusion_bottom_sheet.dart';
import 'package:fusion_mobile_revamped/src/components/permission_request.dart';
import 'package:fusion_mobile_revamped/src/dialpad/dialpad_modal.dart';
import 'package:fusion_mobile_revamped/src/models/contact.dart';
import 'package:fusion_mobile_revamped/src/models/conversations.dart';
import 'package:fusion_mobile_revamped/src/models/dids.dart';
import 'package:fusion_mobile_revamped/src/models/notification_data.dart';
import 'package:fusion_mobile_revamped/src/models/sms_departments.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
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
import 'package:feedback/feedback.dart';

final navigatorKey = GlobalKey<NavigatorState>();
Map<String, dynamic> messageData = {};
registerNotifications() {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
// initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_launcher_background');
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
  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
  HttpClient.enableTimelineLogging = true;
  registerNotifications();
  SharedPreferences sharedPrefs = await SharedPreferences.getInstance();
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
  runApp(OverlaySupport.global(
      child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BetterFeedback(
      feedbackBuilder: (context, onSubmit, scrollController) =>
          FusionFeedbackSheet(
        onSubmit: onSubmit,
        scrollController: scrollController,
      ),
      theme: FeedbackThemeData(
        drawColors: [fusionChats, personalChat, telegramChat, facebookChat],
        background: char,
        feedbackSheetColor: coal,
        bottomSheetTextInputStyle: TextStyle(color: Colors.white),
        bottomSheetDescriptionStyle: TextStyle(color: Colors.white),
        dragHandleColor: Colors.white,
      ),
      child: MyApp(
        sharedPreferences: sharedPrefs,
      ),
    ),
  )));
  // runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  SharedPreferences sharedPreferences;
  late FusionConnection _fusionConnection;
  late Softphone _softphone;
  RemoteMessage? _launchMessage;
  static final GlobalKey navigationKey = GlobalKey<NavigatorState>();
  MyApp({required this.sharedPreferences}) {
    _fusionConnection = FusionConnection(sharedPreferences: sharedPreferences);
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
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          minScaleFactor: 0.8,
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
          sharedPreferences: sharedPreferences,
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
      required this.sharedPreferences,
      this.launchMessage})
      : super(key: key);
  final Softphone softphone;
  final FusionConnection fusionConnection;
  final SharedPreferences sharedPreferences;
  final String? title;
  final RemoteMessage? launchMessage;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  SharedPreferences get sharedPreferences => widget.sharedPreferences;
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
  // late StreamSubscription<ProximityEvent> _proximitySub;
  bool flutterBackgroundInitialized = false;
  Function? onMessagePosted;
  late StreamSubscription<ConnectivityResult> connectivitySubscription;
  ConnectivityResult connectionStatus = ConnectivityResult.none;
  bool relogin = false;
  bool requestPermission = false;

  _logOut() {
    sharedPreferences.remove('username');
    sharedPreferences.remove('sub_login');
    sharedPreferences.remove('aor');
    sharedPreferences.remove('auth_key');
    sharedPreferences.remove('selectedGroupId');

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
  }

  @override
  initState() {
    super.initState();
    receivedMsg = "";
    fusionConnection.onLogOut(_logOut);
    softphone.onUpdate(() {
      setState(() {});
    });
    // _autoLogin();
    _checkLoginStatus();
    // need to move _setupPermissions away from initState
    // or will have error when dart execute in the background
    // specially phone.request
    _setupPermissions();

    _setupFirebase();
    fusionConnection.setRefreshUi(() {
      this.setState(() {});
    });
    connectivitySubscription =
        fusionConnection.connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
    Future.delayed(Duration(seconds: 2), () {
      Connectivity().checkConnectivity().then((value) {
        if (value == ConnectivityResult.none) {
          relogin = true;
          ScaffoldMessenger.of(context).showMaterialBanner(
            MaterialBanner(
              content: Text(
                "No internet connection",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              actions: [
                Icon(
                  Icons.error_outline,
                  color: crimsonDark,
                )
              ],
            ),
          );
        }
      });
    });
  }

  @override
  dispose() {
    connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    connectionStatus = result;
    FusionConnection.isInternetActive =
        await InternetConnectionChecker().hasConnection;
    if (!FusionConnection.isInternetActive) {
      relogin = true;
      ScaffoldMessenger.of(context).showMaterialBanner(
        MaterialBanner(
          content: Text(
            "This device is not connected to the internet",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            Icon(
              Icons.error_outline,
              color: crimsonDark,
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).clearMaterialBanners();
      if (relogin) {
        _checkLoginStatus();
      }
    }
  }

  Future<void> _setupPermissions() async {
    if (!await Permission.notification.isGranted) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );
    }
    if (!await Permission.phone.isGranted) {
      await Permission.phone.request();
    }

    if (Platform.isAndroid) {
      if (!await Permission.bluetoothConnect.isGranted &&
          await Permission.bluetoothConnect.isDenied &&
          !await Permission.bluetoothConnect.isPermanentlyDenied)
        setState(() {
          requestPermission = true;
        });
    }
  }

  checkForInitialMessage({String? username}) async {
    await Firebase.initializeApp();
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage == null && _launchMessage != null) {
      initialMessage = _launchMessage;
      _launchMessage = null;
    }
  }

  checkForIMNotification(Map<String, dynamic> d, {String? username}) async {
    NotificationData notificationData = NotificationData.fromJson(d);
    String depId = notificationData.departmentId ?? DepartmentIds.AllMessages;

    List<SMSDepartment> deps = fusionConnection.smsDepartments.allDepartments();
    if (deps.isEmpty) {
      //TODO:save departments to db for fast access
      await fusionConnection.smsDepartments.getDepartments((p0) => deps = p0);
    }
    if (notificationData.toNumber.isNotEmpty && notificationData.isGroup) {
      SMSDepartment? dep =
          deps.where((element) => element.id == depId).firstOrNull;
      String numberUsed = "";

      List<String> depNumbers = dep?.numbers ?? [];
      List<Contact> convoContacts = [];

      for (String num in notificationData.numbers) {
        if (depNumbers.contains(num) && num != numberUsed) {
          numberUsed = num;
        }
      }
      for (NotificationMember member in notificationData.members) {
        convoContacts.add(Contact.fake(member.number,
            firstName: member.name.split(' ')[0],
            lastName: member.name.split("").length > 1
                ? member.name.split(' ')[1]
                : ""));
      }
      SMSConversation displayingConvo = SMSConversation.build(
          contacts: convoContacts,
          conversationId: int.parse(notificationData.toNumber),
          crmContacts: [],
          selectedDepartmentId: depId,
          hash: notificationData.numbers.join(':'),
          isGroup: notificationData.isGroup,
          myNumber: numberUsed,
          number: notificationData.toNumber);
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => ConversationView(
              conversation: displayingConvo,
              departmentId: depId,
              isNewConversation: displayingConvo.conversationId == null));
    } else if (notificationData.toNumber.isNotEmpty &&
        !notificationData.isGroup) {
      fusionConnection.contacts.search(notificationData.fromNumber, 10, 0,
          (contacts, contactsFromServer, contactsFromPhonebook) {
        if (contactsFromServer || contactsFromPhonebook) {
          fusionConnection.integratedContacts
              .search(notificationData.fromNumber, 10, 0,
                  (crmContacts, fromServer, hasMore) {
            if (fromServer || contactsFromPhonebook) {
              if (!fusionConnection.settings.usesV2) {
                contacts.addAll(crmContacts);
              }
              fusionConnection.messages
                  .checkExistingConversation(depId, notificationData.toNumber,
                      [notificationData.fromNumber], contacts)
                  .then(
                (convo) {
                  SMSDepartment? department = fusionConnection.smsDepartments
                      .getDepartmentByPhoneNumber(notificationData.toNumber);
                  showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) => ConversationView(
                          conversation: convo,
                          departmentId: depId == DepartmentIds.AllMessages
                              ? department?.id ?? DepartmentIds.Personal
                              : depId,
                          isNewConversation: convo.conversationId == null));
                },
              );
            }
          });
        }
      });
    }
  }

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
          icon: "@mipmap/new_app_icon",
        );

        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);
        flutterLocalNotificationsPlugin.show(
          Random().nextInt(1000),
          message.data['title'],
          message.data['body'],
          platformChannelSpecifics,
        );
        messageData = message.data;
      }
    }
  }

  _checkLoginStatus() async {
    String? username = sharedPreferences.getString("username");
    if (username != null && username.isNotEmpty) {
      String domain = username.split('@')[1];
      String sub_login = sharedPreferences.getString("sub_login") ?? "";
      String aor = sharedPreferences.getString("aor") ?? "";
      String auth_key = sharedPreferences.getString("auth_key") ?? "";
      String ext = username.split('@')[0];
      if (auth_key.isNotEmpty) {
        setState(() {
          _sub_login = sub_login;
          _auth_key = auth_key;
          _aor = aor;
          _logged_in = true;
          _isRegistering = true;
        });
        fusionConnection.autoLogin(username, _logOut);
        softphone.register(sub_login, auth_key, aor.replaceAll('sip:', ''));
        softphone.onUnregister(() {
          fusionConnection.nsApiCall('device', 'read', {
            'domain': domain,
            'device': 'sip:${ext}fy@$domain',
            'user': ext
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

            sharedPreferences.setString("sub_login", _sub_login);
            sharedPreferences.setString("auth_key", _auth_key);
            sharedPreferences.setString("aor", _aor);

            softphone.register(
                _sub_login, _auth_key, _aor.replaceAll('sip:', ''));
          });
        });
        checkForInitialMessage(username: username);
      } else {}
    }
  }

  Future<void> _register({String? username}) async {
    if (_isRegistering) {
      return;
    } else if (_sub_login.isNotEmpty &&
        _auth_key.isNotEmpty &&
        _aor.isNotEmpty) {
      softphone.register(_sub_login, _auth_key, _aor.replaceAll('sip:', ''));
    } else {
      String _domain = fusionConnection.getDomain();
      String _ext = fusionConnection.getExtension();
      if (username != null) {
        _domain = username.split("@")[1];
        _ext = username.split("@")[0];
      }
      fusionConnection.nsApiCall('device', 'read', {
        'domain': _domain,
        'device': 'sip:${_ext}fy@${_domain}',
        'user': _ext
      }, callback: (Map<String, dynamic> response) {
        if (!response.containsKey('device')) {
          toast(
              "You don't seem to have a fusion mobile device registered, please contact support.",
              duration: Toast.LENGTH_LONG);
          fusionConnection.logOut();
        } else {
          Map<String, dynamic> device = response['device'];
          _sub_login = device['sub_login'];
          _auth_key = device['authentication_key'];
          _aor = device['aor'];

          sharedPreferences.setString("sub_login", _sub_login);
          sharedPreferences.setString("auth_key", _auth_key);
          sharedPreferences.setString("aor", _aor);

          softphone.register(device['sub_login'], device['authentication_key'],
              device['aor'].replaceAll('sip:', ''));
        }
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

  void _loginSuccess(String username) {
    this.setState(() {
      _logged_in = true;
    });
    _register(username: username);
    // checkForInitialMessage();
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
    } else {
      return null;
    }
  }

  _getTabWidget() {
    return (_currentIndex == 0
        ? RecentCallsTab(fusionConnection, softphone)
        : (_currentIndex == 1
            ? RecentContactsTab(fusionConnection, softphone)
            : Chats(
                fusionConnection: fusionConnection,
                softPhone: softphone,
                sharedPreferences: sharedPreferences,
              )));
  }

  @override
  Widget build(BuildContext context) {
    if (softphone.activeCall != null &&
        softphone.isConnected(softphone.activeCall!) != null &&
        !softphone.getHoldState(softphone.activeCall) &&
        !softphone.isSpeakerEnabled() &&
        !_isProximityListening) {
      _isProximityListening = true;
      // _proximitySub = proximityEvents!.listen((ProximityEvent event) {
      //   setState(() {});
      // });
    } else if (_isProximityListening &&
        (softphone.activeCall == null ||
            softphone.getHoldState(softphone.activeCall) ||
            softphone.isSpeakerEnabled())) {
      _isProximityListening = false;
      // _proximitySub.cancel();
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
    if (requestPermission) {
      return PermissionRequestScreen(
        permissionRequest: PermissionRequest(
          "Enable Bluetooth",
          Image.asset("assets/icons/BTDevices.png"),
          "Fusion needs access to discover connected Bluetooth devices",
          Permission.bluetoothConnect,
          () => setState(() => requestPermission = false),
        ),
      );
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
