//
//  ConversationsVM.swift
//  Runner
//
//  Created by Zaid on 6/24/24.
//

import Foundation
class ConversationsVM:NSObject {
    var conversationsMethodChannel: FlutterMethodChannel?
    
    public init(conversationsMethodChannel: FlutterMethodChannel? = nil) {
        self.conversationsMethodChannel = conversationsMethodChannel
        super.init()
        self.conversationsMethodChannel?.setMethodCallHandler({
          (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if(call.method == "detectAddress"){
                let args = call.arguments as? [String]
                return result(self.detectAddress(text: args?[0] ?? ""))
            }
          })
    }
    
    func detectAddress (text:String) -> String {
        let detectorType: NSTextCheckingResult.CheckingType = [ .address ]
        var newtext = text
        do {
           let detector = try NSDataDetector(types: detectorType.rawValue)
           let matches = detector.matches(
            in: newtext,
            options: [],
            range: NSRange(location: 0, length: text.count)
           )
            
            for match in matches {
                if let range = Range(match.range, in: newtext) {
                    if(match.addressComponents?[.street] != nil) {
                        let street = match.addressComponents![.street]!.replacingOccurrences(of: " ", with: "+")
                        let city = match.addressComponents?[.city]?.replacingOccurrences(of: " ", with: "+")
                        let state = match.addressComponents?[.state]
                        let zip = match.addressComponents?[.zip]
//                        print("MDBM \(match.addressComponents)")
                        newtext.replaceSubrange(
                            range,
                            with:
                                "https://maps.apple.com/?q=\(street)\(city != nil ? "+\(city!)" : "")\(state != nil ? "+\(state!)": "")\(zip != nil ? "+\(zip!)":"")"
                        )
                    }
                }
            }

         } catch {
            print("handle error")
         }
        return newtext
    }
}
