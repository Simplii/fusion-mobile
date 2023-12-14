//
//  StartCallIntentHandler.swift
//  Runner
//
//  Created by Zaid on 12/1/23.
//

import Foundation
import Intents
import os

extension NSUserActivity: StartCallConvertible {

    var startCallHandle: String? {
        let startCallIntent = interaction?.intent as? INStartCallIntent
        guard let startCallIntent = interaction?.intent as? INStartCallIntent,
            let personHandle = startCallIntent.contacts?.first?.personHandle
            else {
                return nil
        }
        if #available(iOS 14.0, *) {
            var logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "MDBM")
            logger.log("number to call \(personHandle, privacy: .public)")
        } else {
            // Fallback on earlier versions
        }
        
        return personHandle.value
    }

    var isVideo: Bool? {
        guard let startCallIntent = interaction?.intent as? INStartCallIntent else { return nil }
        return startCallIntent.callCapability == .videoCall
    }

}
