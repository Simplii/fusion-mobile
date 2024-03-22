//
//  CallQualityStream.swift
//  Runner
//
//  Created by Zaid on 3/22/24.
//

import Foundation
import Flutter
import linphonesw

class CallInfoStream: NSObject, FlutterStreamHandler {
    private var timer: Timer?
    private let pd: ProviderDelegate
    
    public init(providerDelegate:ProviderDelegate) {
        pd = providerDelegate
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink event: @escaping FlutterEventSink) -> FlutterError? {

        var call: Call? = pd.mCore?.currentCall
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { t in
                event(call?.currentQuality)
                if (call?.state == Call.State.Released ||
                    call?.state == Call.State.End ||
                    call?.state == Call.State.Error ||
                    call?.state == Call.State.Paused
                ) {
                    call = self.pd.mCore?.currentCall
                    if(call == nil){
                        t.invalidate()
                    }
                    
                }
            })
        }
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        timer?.invalidate()
        return nil
    }
    
    
}

