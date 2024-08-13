import UIKit
import Intents
import CallKit
import Flutter
import PushKit
import AVFoundation
import linphonesw
import Firebase
import Foundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate{
    
    var providerDelegate: ProviderDelegate!
    var callkitChannel: FlutterMethodChannel!
    var contactsChannel: FlutterMethodChannel!
    var callInfoEventChannel: FlutterEventChannel?
    var contactsProvider: ContactsProvider?
    var conversationsChannel: FlutterMethodChannel?
//    var loggingServiceManager = LoggingServiceManager()
    
    var timer = Timer()
    
    static func shared() -> AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }
    
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("opened from url")
        print(url)
        return true
    }
    
    internal override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        guard let handle = userActivity.startCallHandle else {
            return false
        }
        let matchNonNumeric = "[^0-9]+"
        let domain: String? = UserDefaults().string(forKey: "domain")
        var address = "sip:" + handle.replacingOccurrences(of: matchNonNumeric, with: "", options: [.regularExpression ]) + "@" + (domain ?? providerDelegate.domain)
        if (address.count == 11 && address.starts(with: "1")){
            address.replaceSubrange(...address.startIndex, with:"")
        }
        // for call intents, we need to wait until phone registration is complete before placing
        // a call.
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.2,
            repeats: true,
            block: { _ in
                if(self.providerDelegate.regState == RegistrationState.Ok){
                    self.providerDelegate.outgoingCall(address: address)
                    self.timer.invalidate()
                }
            }
        )
            
        return true
    }
    
    
//    @available(iOS 13.0, *)
//    func handle(startWorkout intent: INStartCallIntent,
//                completion: @escaping (INStartWorkoutIntentResponse) -> Void) {
//        print("hadle instartcallintent")
//        print(intent.contacts)
//    }
//
//    func handle(startWorkout intent: INStartAudioCallIntent,
//                completion: @escaping (INStartWorkoutIntentResponse) -> Void) {
//        print("hadle instartcallaudiointent")
//        print(intent.identifier)
//        print(intent)
//    }
//
//    func application(
//        _ application: UIApplication,
//        handlerFor intent: INIntent) {
//            print("startedfromintent")
//            print(intent)
//            print(intent.identifier)
//            print(intent.classForCoder)
//            print(intent.intentDescription)
//    }
    
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let mainQueue = DispatchQueue.main
        let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [PKPushType.voIP]
        
        if (voipRegistry.pushToken(for: .voIP) != nil) {
            let deviceToken: String = voipRegistry.pushToken(for: .voIP)!.map { String(format: "%02x", $0 as CVarArg) }.joined();
            
            if (callkitChannel != nil) {
                callkitChannel.invokeMethod("setPushToken", arguments: [deviceToken]);
                
            }
        }
    }

    override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        print("providerpush app delegate starting")
        
        setupCallkitFlutterLink()
//        providerDelegate = ProviderDelegate(channel: callkitChannel, loggingService: loggingServiceManager)
        providerDelegate = ProviderDelegate(channel: callkitChannel)
        contactsProvider = ContactsProvider(channel: contactsChannel)
        ConversationsVM(conversationsMethodChannel: conversationsChannel)
        let callQualityStream = CallInfoStream(providerDelegate: providerDelegate)
        callInfoEventChannel?.setStreamHandler(callQualityStream)
        FirebaseApp.configure() //add this before the code below

        GeneratedPluginRegistrant.register(with: self)
        
        let mainQueue = DispatchQueue.main
        let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [PKPushType.voIP]
        
        if (voipRegistry.pushToken(for: .voIP) != nil) {
            let deviceToken: String = voipRegistry.pushToken(for: .voIP)!.map { String(format: "%02x", $0 as CVarArg) }.joined();
            
            if (callkitChannel != nil) {
                callkitChannel.invokeMethod("setPushToken", arguments: [deviceToken]);
            }
        }
        
        UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge]) {
                        [weak self] granted, error in
                        guard let _ = self else {return}
                        guard granted else { return }
                        self?.getNotificationSettings() }
        
        
/*        do {
            Client()
          Client.shared = try Client(dsn: "https://6ac1552d08264600966c0ec85516dbd9@o68456.ingest.sentry.io/146230")
                try Client.shared?.startCrashHandler()
        } catch let error {
            print("\(error)")
        }*/
        UIApplication.shared.applicationIconBadgeNumber = 0
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        print("opened from scene")
        print(scene)
        print(connectionOptions)
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        print("did become active");
    }
    
    func setupCallkitFlutterLink() {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        callkitChannel = FlutterMethodChannel(
            name: "net.fusioncomm.ios/callkit",
            binaryMessenger: controller.binaryMessenger)
        contactsChannel = FlutterMethodChannel(
            name: "net.fusioncomm.ios/contacts",
            binaryMessenger: controller.binaryMessenger)
        callInfoEventChannel = FlutterEventChannel(
            name: "channel/callInfo",
            binaryMessenger: controller.binaryMessenger
        )
        conversationsChannel = FlutterMethodChannel(
            name: "channel/conversations",
            binaryMessenger: controller.binaryMessenger
        )
    }

    
        
        func getNotificationSettings() {
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    UNUserNotificationCenter.current().delegate = self
                    guard settings.authorizationStatus == .authorized else { return }
                    let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(expirationHandler: nil)
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
                    }
                }
            } else {
                let settings = UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil)
                UIApplication.shared.registerUserNotificationSettings(settings)
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    
    func pushRegistry(_ registry: PKPushRegistry,
            didUpdate pushCredentials: PKPushCredentials,
            for type: PKPushType) {
        print("didpudategreds providerpush")
        print(pushCredentials)
        let deviceToken: String = pushCredentials.token.map { String(format: "%02x", $0) }.joined();

        if (callkitChannel != nil) {
            callkitChannel.invokeMethod("setPushToken", arguments: [deviceToken]);
        }
    }
    
    func pushRegistry(_ registry: PKPushRegistry,
                      didInvalidatePushTokenFor type: PKPushType) {
        print("didinvalidate providerpush")
        print(type)
    }
    
    func pushRegistry(_ registry: PKPushRegistry,
                        didReceiveIncomingPushWith payload: PKPushPayload,
                        for type: PKPushType, completion: @escaping () -> Void) {
        print("didrecproviderpush callkit", payload, payload.dictionaryPayload)
    

        if let uuidString = payload.dictionaryPayload["uuid"] as? String,
          let identifier = payload.dictionaryPayload["caller_name"] as? String,
          let handle = payload.dictionaryPayload["caller_id"] as? String,
          let uuid = UUID(uuidString: uuidString) {
        
        providerDelegate.reportNewIncomingCall(
              uuid: uuid,
              handle: handle,
              callerName: identifier,
            hasVideo: false) { (e: Error?) in
            print("completion")

        };
            
      } else if let identifier = payload.dictionaryPayload["caller_name"] as? String,
                let handle = payload.dictionaryPayload["caller_id"] as? String{
        let uuid = UUID()
              providerDelegate.reportNewIncomingCall(
                    uuid: uuid,
                    handle: handle,
                    callerName: identifier,
                  hasVideo: false) { (e: Error?) in
                  print("completion2")
    
              };
                  
            }
    else {
        providerDelegate.reportNewIncomingCall(uuid: UUID(), handle: "Unknown", callerName: "Unknown") {(e: Error?) in print("completion3"); };
        }
    }
}


//@available(iOS 10.0, *)
//protocol SupportedStartCallIntent {
//    var contacts: [INPerson]? { get }
//}
//
//@available(iOS 10.0, *)
//extension INStartAudioCallIntent: SupportedStartCallIntent {}
//
//@available(iOS 10.0, *)
//extension NSUserActivity {
//
//    var startCallHandle: String? {
//        guard let startCallIntent = interaction?.intent as? SupportedStartCallIntent else {
//            return nil
//        }
//        return startCallIntent.contacts?.first?.personHandle?.value
//    }
//
//}


