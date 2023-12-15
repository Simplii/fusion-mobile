//
//  IntentHandler.swift
//  IntentsExtension
//
//  Created by Zaid on 12/4/23.
//

import Intents

class IntentHandler: INExtension, INStartCallIntentHandling {

    func handle(intent: INStartCallIntent, completion: @escaping (INStartCallIntentResponse) -> Void) {

        let response: INStartCallIntentResponse

        defer {
            completion(response)
        }

        // Ensure there is a person handle.
        guard intent.contacts?.first?.personHandle != nil else {
            response = INStartCallIntentResponse(code: .failure, userActivity: nil)
            return
        }

        let userActivity = NSUserActivity(activityType: String(describing: INStartCallIntent.self))

        response = INStartCallIntentResponse(code: .continueInApp, userActivity: userActivity)
    }

}
