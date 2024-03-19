package net.fusioncomm.android.telecom

import android.telecom.CallAudioState
import net.fusioncomm.android.FMCore
import org.linphone.core.AudioDevice
import org.linphone.core.Call
import org.linphone.core.tools.Log

//Audio routing helper class for Linphone
class AudioRouteUtils {
    companion object {
        private fun applyAudioRouteChange(
            call: Call?,
            types: List<AudioDevice.Type>,
            output: Boolean = true
        ) {
            val currentCall = if (FMCore.core.callsNb > 0) {
                call ?: FMCore.core.currentCall ?: FMCore.core.calls[0]
            } else {
                Log.w("[Audio Route Helper] No call found, setting audio route on Core")
                null
            }
            val conference = FMCore.core.conference
            val capability = if (output) {
                AudioDevice.Capabilities.CapabilityPlay
            } else {
                AudioDevice.Capabilities.CapabilityRecord
            }
            val preferredDriver = if (output) {
                FMCore.core.defaultOutputAudioDevice?.driverName
            } else {
                FMCore.core.defaultInputAudioDevice?.driverName
            }

            val extendedAudioDevices = FMCore.core.extendedAudioDevices
            Log.d(
                "[Audio Route Helper] Looking for an ${if (output) "output" else "input"} audio device with capability [$capability], driver name [$preferredDriver] and type [$types] in extended audio devices list (size ${extendedAudioDevices.size})"
            )
            val foundAudioDevice = extendedAudioDevices.find {
                it.driverName == preferredDriver && types.contains(it.type) && it.hasCapability(
                    capability
                )
            }
            val audioDevice = if (foundAudioDevice == null) {
                Log.w(
                    "[Audio Route Helper] Failed to find an audio device with capability [$capability], driver name [$preferredDriver] and type [$types]"
                )
                extendedAudioDevices.find {
                    types.contains(it.type) && it.hasCapability(capability)
                }
            } else {
                foundAudioDevice
            }

            if (audioDevice == null) {
                Log.e(
                    "[Audio Route Helper] Couldn't find audio device with capability [$capability] and type [$types]"
                )
                for (device in extendedAudioDevices) {
                    // TODO: switch to debug?
                    Log.i(
                        "[Audio Route Helper] Extended audio device: [${device.deviceName} (${device.driverName}) ${device.type} / ${device.capabilities}]"
                    )
                }
                return
            }
            if (conference != null && conference.isIn) {
                Log.i(
                    "[Audio Route Helper] Found [${audioDevice.type}] ${if (output) "playback" else "recorder"} audio device [${audioDevice.deviceName} (${audioDevice.driverName})], routing conference audio to it"
                )
                if (output) {
                    conference.outputAudioDevice = audioDevice
                } else {
                    conference.inputAudioDevice = audioDevice
                }
            } else if (currentCall != null) {
                Log.i(
                    "[Audio Route Helper] Found [${audioDevice.type}] ${if (output) "playback" else "recorder"} audio device [${audioDevice.deviceName} (${audioDevice.driverName})], routing call audio to it"
                )
                if (output) {
                    currentCall.outputAudioDevice = audioDevice
                } else {
                    currentCall.inputAudioDevice = audioDevice
                }
            } else {
                Log.i(
                    "[Audio Route Helper] Found [${audioDevice.type}] ${if (output) "playback" else "recorder"} audio device [${audioDevice.deviceName} (${audioDevice.driverName})], changing core default audio device"
                )
                if (output) {
                    FMCore.core.outputAudioDevice = audioDevice
                } else {
                    FMCore.core.inputAudioDevice = audioDevice
                }
            }
        }

        private fun routeAudioTo(
            call: Call?,
            types: List<AudioDevice.Type>,
            skipTelecom: Boolean = false
        ) {
            val currentCall = call ?: FMCore.core.currentCall ?: FMCore.core.calls.firstOrNull()
            if (currentCall != null && !skipTelecom ) {
                Log.i(
                    "[Audio Route Helper] Call provided & Telecom Helper exists, trying to dispatch audio route change through Telecom API"
                )
                val connection = CallsManager.findConnectionForCallId(
                    currentCall.callLog.callId
                )
                if (connection != null) {
                    val route = when (types.first()) {
                        AudioDevice.Type.Earpiece -> CallAudioState.ROUTE_EARPIECE
                        AudioDevice.Type.Speaker -> CallAudioState.ROUTE_SPEAKER
                        AudioDevice.Type.Headphones, AudioDevice.Type.Headset -> CallAudioState.ROUTE_WIRED_HEADSET
                        AudioDevice.Type.Bluetooth, AudioDevice.Type.BluetoothA2DP -> CallAudioState.ROUTE_BLUETOOTH
                        else -> CallAudioState.ROUTE_WIRED_OR_EARPIECE
                    }
                    Log.i(
                        "[Audio Route Helper] Telecom Helper & matching connection found, dispatching audio route change through it"
                    )

                    applyAudioRouteChange(currentCall, types)

                } else {
                    Log.w("[Audio Route Helper] Telecom Helper found but no matching connection!")
                    applyAudioRouteChange(currentCall, types)
                }
            } else {
                applyAudioRouteChange(call, types)
            }
        }

        fun routeAudioToEarpiece(call: Call? = null, skipTelecom: Boolean = false) {
            routeAudioTo(call, arrayListOf(AudioDevice.Type.Earpiece), skipTelecom)
        }

        fun routeAudioToSpeaker(call: Call? = null, skipTelecom: Boolean = false) {
            routeAudioTo(call, arrayListOf(AudioDevice.Type.Speaker), skipTelecom)
        }

        fun routeAudioToBluetooth(call: Call? = null, skipTelecom: Boolean = false) {
            routeAudioTo(
                call,
                arrayListOf(AudioDevice.Type.Bluetooth),
                skipTelecom
            )
        }

        fun routeAudioToHeadset(call: Call? = null, skipTelecom: Boolean = false) {
            routeAudioTo(
                call,
                arrayListOf(AudioDevice.Type.Headphones, AudioDevice.Type.Headset),
                skipTelecom
            )
        }

        fun isSpeakerAudioRouteCurrentlyUsed(call: Call? = null): Boolean {
            val currentCall = if (FMCore.core.callsNb > 0) {
                call ?: FMCore.core.currentCall ?: FMCore.core.calls[0]
            } else {
                Log.w("[Audio Route Helper] No call found, checking audio route on Core")
                null
            }
            val conference = FMCore.core.conference

            val audioDevice = if (conference != null && conference.isIn) {
                conference.outputAudioDevice
            } else if (currentCall != null) {
                currentCall.outputAudioDevice
            } else {
                FMCore.core.outputAudioDevice
            }

            if (audioDevice == null) return false
            Log.i(
                "[Audio Route Helper] Playback audio device currently in use is [${audioDevice.deviceName} (${audioDevice.driverName}) ${audioDevice.type}]"
            )
            return audioDevice.type == AudioDevice.Type.Speaker
        }

        fun isBluetoothAudioRouteCurrentlyUsed(call: Call? = null): Boolean {
            if (FMCore.core.callsNb == 0) {
                Log.w("[Audio Route Helper] No call found, so bluetooth audio route isn't used")
                return false
            }
            val currentCall = call ?: FMCore.core.currentCall ?: FMCore.core.calls[0]
            val conference = FMCore.core.conference

            val audioDevice = if (conference != null && conference.isIn) {
                conference.outputAudioDevice
            } else {
                currentCall.outputAudioDevice
            }

            if (audioDevice == null) return false
            Log.i(
                "[Audio Route Helper] Playback audio device currently in use is [${audioDevice.deviceName} (${audioDevice.driverName}) ${audioDevice.type}]"
            )
            return audioDevice.type == AudioDevice.Type.Bluetooth
        }

        fun isBluetoothAudioRouteAvailable(): Boolean {
            for (audioDevice in FMCore.core.audioDevices) {
                if ((audioDevice.type == AudioDevice.Type.Bluetooth) &&
                    audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityPlay)
                ) {
                    Log.i(
                        "[Audio Route Helper] Found bluetooth audio device [${audioDevice.deviceName} (${audioDevice.driverName})]"
                    )
                    return true
                }
            }
            return false
        }

        private fun isBluetoothAudioRecorderAvailable(): Boolean {
            for (audioDevice in FMCore.core.audioDevices) {
                if ((audioDevice.type == AudioDevice.Type.Bluetooth ) &&
                    audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityRecord)
                ) {
                    Log.i(
                        "[Audio Route Helper] Found bluetooth audio recorder [${audioDevice.deviceName} (${audioDevice.driverName})]"
                    )
                    return true
                }
            }
            return false
        }

        fun isHeadsetAudioRouteAvailable(): Boolean {
            for (audioDevice in FMCore.core.audioDevices) {
                if ((audioDevice.type == AudioDevice.Type.Headset || audioDevice.type == AudioDevice.Type.Headphones) &&
                    audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityPlay)
                ) {
                    Log.i(
                        "[Audio Route Helper] Found headset/headphones audio device [${audioDevice.deviceName} (${audioDevice.driverName})]"
                    )
                    return true
                }
            }
            return false
        }

        private fun isHeadsetAudioRecorderAvailable(): Boolean {
            for (audioDevice in FMCore.core.audioDevices) {
                if ((audioDevice.type == AudioDevice.Type.Headset || audioDevice.type == AudioDevice.Type.Headphones) &&
                    audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityRecord)
                ) {
                    Log.i(
                        "[Audio Route Helper] Found headset/headphones audio recorder [${audioDevice.deviceName} (${audioDevice.driverName})]"
                    )
                    return true
                }
            }
            return false
        }

        fun getAudioPlaybackDeviceIdForCallRecordingOrVoiceMessage(): String? {
            // In case no headphones/headset/hearing aid/bluetooth is connected, use speaker sound card to play recordings, otherwise use earpiece
            // If none are available, default one will be used
            var headphonesCard: String? = null
            var bluetoothCard: String? = null
            var speakerCard: String? = null
            var earpieceCard: String? = null
            for (device in FMCore.core.audioDevices) {
                if (device.hasCapability(AudioDevice.Capabilities.CapabilityPlay)) {
                    when (device.type) {
                        AudioDevice.Type.Headphones, AudioDevice.Type.Headset -> {
                            headphonesCard = device.id
                        }
                        AudioDevice.Type.Bluetooth -> {
                            bluetoothCard = device.id
                        }
                        AudioDevice.Type.Speaker -> {
                            speakerCard = device.id
                        }
                        AudioDevice.Type.Earpiece -> {
                            earpieceCard = device.id
                        }
                        else -> {}
                    }
                }
            }
            Log.i(
                "[Audio Route Helper] Found headset/headphones/hearingAid sound card [$headphonesCard], bluetooth sound card [$bluetoothCard], speaker sound card [$speakerCard] and earpiece sound card [$earpieceCard]"
            )
            return headphonesCard ?: bluetoothCard ?: speakerCard ?: earpieceCard
        }

        fun getAudioRecordingDeviceForVoiceMessage(): AudioDevice? {
            // In case no headphones/headset/hearing aid/bluetooth is connected, use microphone
            // If none are available, default one will be used
            var bluetoothAudioDevice: AudioDevice? = null
            var headsetAudioDevice: AudioDevice? = null
            var builtinMicrophone: AudioDevice? = null
            for (device in FMCore.core.audioDevices) {
                if (device.hasCapability(AudioDevice.Capabilities.CapabilityRecord)) {
                    when (device.type) {
                        AudioDevice.Type.Bluetooth -> {
                            bluetoothAudioDevice = device
                        }
                        AudioDevice.Type.Headset, AudioDevice.Type.Headphones -> {
                            headsetAudioDevice = device
                        }
                        AudioDevice.Type.Microphone -> {
                            builtinMicrophone = device
                        }
                        else -> {}
                    }
                }
            }
            Log.i(
                "[Audio Route Helper] Found headset/headphones/hearingAid [${headsetAudioDevice?.id}], bluetooth [${bluetoothAudioDevice?.id}] and builtin microphone [${builtinMicrophone?.id}]"
            )
            return headsetAudioDevice ?: bluetoothAudioDevice ?: builtinMicrophone
        }
    }
}

