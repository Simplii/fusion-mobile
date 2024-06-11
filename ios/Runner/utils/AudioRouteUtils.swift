//
//  AudioRouteUtils.swift
//  Runner
//
//  Created by Zaid on 6/6/24.
//

import Foundation
import AVFoundation
import linphonesw

class AudioRouteUtils : NSObject {
    static var core:Core = AppDelegate.shared().providerDelegate.mCore!
    static let DebugTag = "MDBM AudioRouteUtil"
    
    static private func applyAudioRouteChange( call: Call?, types: [AudioDevice.Kind], output: Bool = true) {
        let typesNames = types.map { String(describing: $0) }.joined(separator: "/")
        
        let currentCall = core.callsNb > 0 ? (call != nil) ? call : core.currentCall != nil ? core.currentCall : core.calls[0] : nil
        if (currentCall == nil) {
            print("\(DebugTag) No call found, setting audio route on Core")
        }
        let conference = core.conference
        let capability = output ? AudioDevice.Capabilities.CapabilityPlay : AudioDevice.Capabilities.CapabilityRecord

        var found = false
        
        core.audioDevices.forEach { (audioDevice) in
            print("\(DebugTag) registered coe audio devices are : [\(audioDevice.deviceName)] [\(audioDevice.type)] [\(audioDevice.capabilities)] ")
        }

        core.audioDevices.forEach { (audioDevice) in
            if (!found && types.contains(audioDevice.type) && audioDevice.hasCapability(capability: capability)) {
                if (conference != nil && conference?.isIn == true) {
                    print("\(DebugTag) Found [\(audioDevice.type)] \(output ?  "playback" : "recorder") audio device [\(audioDevice.deviceName)], routing conference audio to it")
                    if (output) {
                        conference?.outputAudioDevice = audioDevice
                    } else {
                        conference?.inputAudioDevice = audioDevice
                    }
                } else if (currentCall != nil) {
                    print("\(DebugTag) Found [\(audioDevice.type)] \(output ?  "playback" : "recorder") audio device [\(audioDevice.deviceName)], routing call audio to it")
                    if (output) {
                        currentCall?.outputAudioDevice = audioDevice
                    }
                    else {
                        currentCall?.inputAudioDevice = audioDevice
                    }
                } else {
                    print("\(DebugTag)Found [\(audioDevice.type)] \(output ?  "playback" : "recorder") audio device [\(audioDevice.deviceName)], changing core default audio device")
                    if (output) {
                        core.outputAudioDevice = audioDevice
                    } else {
                        core.inputAudioDevice = audioDevice
                    }
                }
                found = true
            }
        }
        if (!found) {
            print("\(DebugTag) Couldn't find \(typesNames) audio device")
        }
    }
    
    static private func isBluetoothAudioRecorderAvailable() -> Bool {
        if let device = core.audioDevices.first(where: { $0.type == AudioDevice.Kind.Bluetooth &&  $0.hasCapability(capability: .CapabilityRecord) }) {
            print("\(DebugTag) Found bluetooth audio recorder [\(device.deviceName)]")
            return true
        }
        return false
    }

    static func isHeadsetAudioRouteAvailable() -> Bool {
        if let device = core.audioDevices.first(where: { ($0.type == AudioDevice.Kind.Headset||$0.type == AudioDevice.Kind.Headphones) &&  $0.hasCapability(capability: .CapabilityPlay) }) {
            print("\(DebugTag) Found headset/headphones audio device  [\(device.deviceName)]")
            return true
        }
        return false
    }
    
    static private func isHeadsetAudioRecorderAvailable() -> Bool {
        if let device = core.audioDevices.first(where: { ($0.type == AudioDevice.Kind.Headset||$0.type == AudioDevice.Kind.Headphones) &&  $0.hasCapability(capability: .CapabilityRecord) }) {
            print("\(DebugTag) Found headset/headphones audio recorder  [\(device.deviceName)]")
            return true
        }
        return false
    }

    
    static private func changeCaptureDeviceToMatchAudioRoute(call: Call?, types: [AudioDevice.Kind]) {
        switch (types.first) {
        case .Bluetooth :if (isBluetoothAudioRecorderAvailable()) {
            print("\(DebugTag) Bluetooth device is able to record audio, also change input audio device")
            applyAudioRouteChange(call: call, types: [AudioDevice.Kind.Bluetooth], output: false)
        }
        case .Headset, .Headphones : if (isHeadsetAudioRecorderAvailable()) {
            print("\(DebugTag) Headphones/headset device is able to record audio, also change input audio device")
            applyAudioRouteChange(call:call,types: [AudioDevice.Kind.Headphones, AudioDevice.Kind.Headset], output:false)
        }
        default: applyAudioRouteChange(call:call,types: [AudioDevice.Kind.Microphone], output:false)
        }
    }

    
    static private func routeAudioTo( call: Call?, types: [AudioDevice.Kind]) {
        let currentCall = call != nil ? call : core.currentCall != nil ? core.currentCall : (core.callsNb > 0 ? core.calls[0] : nil)
        if (call != nil || currentCall != nil) {
            let callToUse = call != nil ? call : currentCall
            applyAudioRouteChange(call: callToUse, types: types)
            changeCaptureDeviceToMatchAudioRoute(call: callToUse, types: types)
        } else {
            applyAudioRouteChange(call: call, types: types)
            changeCaptureDeviceToMatchAudioRoute(call: call, types: types)
        }
    }

    
    
    static func routeAudioToEarpiece(call: Call? = nil) {
        routeAudioTo(call: call, types: [AudioDevice.Kind.Microphone]) // on iOS Earpiece = Microphone
    }
        
    static func routeAudioToSpeaker(call: Call? = nil) {
        routeAudioTo(call: call, types: [AudioDevice.Kind.Speaker])
    }
    
    static func routeAudioToBluetooth(call: Call? = nil) {
        routeAudioTo(call: call, types: [AudioDevice.Kind.Bluetooth])
    }

//    static func isBluetoothDeviceConnected(audioSession: AVAudioSession) -> Bool {
//        let bluetoothPortTypes: Set<AVAudioSession.Port> = [.bluetoothA2DP, .bluetoothLE,
//                                                            .bluetoothHFP, .headphones]
//        for output in audioSession.currentRoute.outputs {
//            if bluetoothPortTypes.contains(output.portType) {
//                return true
//            }
//        }
//        return false
//    }
    
}
