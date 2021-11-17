import UIKit
import CallKit
import Flutter
import PushKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate{
    
    var providerDelegate: ProviderDelegate!
    var callkitChannel: FlutterMethodChannel!

    override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        print("providerpush app delegate starting")
        
        setupCallkitFlutterLink()
        providerDelegate = ProviderDelegate(channel: callkitChannel)

        GeneratedPluginRegistrant.register(with: self)

        let mainQueue = DispatchQueue.main
        let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [PKPushType.voIP]
        
        UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge]) {
                        [weak self] granted, error in
                        guard let _ = self else {return}
                        guard granted else { return }
                        self?.getNotificationSettings() }
        
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func setupCallkitFlutterLink() {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        callkitChannel = FlutterMethodChannel(
            name: "net.fusioncomm.ios/callkit",
            binaryMessenger: controller.binaryMessenger)
    }

    
        
        func getNotificationSettings() {
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    UNUserNotificationCenter.current().delegate = self
                    guard settings.authorizationStatus == .authorized else { return }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
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
    }
    
    func pushRegistry(_ registry: PKPushRegistry,
                      didInvalidatePushTokenFor type: PKPushType) {
        print("didinvalidate providerpush")
        print(type)
    }
    
    func pushRegistry(_ registry: PKPushRegistry,
                        didReceiveIncomingPushWith payload: PKPushPayload,
                        for type: PKPushType, completion: @escaping () -> Void) {
        print("didrecproviderpush", payload, payload.dictionaryPayload  )
  
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
            
      }
    }
}

