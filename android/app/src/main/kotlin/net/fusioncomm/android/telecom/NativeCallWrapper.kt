package net.fusioncomm.android.telecom

import android.annotation.TargetApi
import android.content.Context
import android.os.Build
import android.telecom.CallAudioState
import android.telecom.CallEndpoint
import android.telecom.Connection
import android.telecom.DisconnectCause
import android.util.Log
import net.fusioncomm.android.FMCore
import org.linphone.core.Call


class NativeCallWrapper(var callId: String, val context: Context) : Connection() {
    private val debugTag = "MDBM CallWrapper"

    init {
        Log.d(debugTag, "INIT")
        val properties = connectionProperties or PROPERTY_SELF_MANAGED
        connectionProperties = properties

        val capabilities = connectionCapabilities or CAPABILITY_MUTE or CAPABILITY_SUPPORT_HOLD or CAPABILITY_HOLD
        connectionCapabilities = capabilities

        audioModeIsVoip = true
    }

    @TargetApi(34)
    override fun onCallEndpointChanged(callEndpoint: CallEndpoint) {
        // api 34 uses this instead of onCallAudioStateChanged
        Log.d(debugTag, "Call endpoint changed ${callEndpoint.endpointName}")
    }
    @TargetApi(34)
    override fun onAvailableCallEndpointsChanged(availableEndpoints: MutableList<CallEndpoint>) {
        // api 34 uses this instead of onCallAudioStateChanged for new list of devices
        AudioRouteUtils.availableCallEndpoints = availableEndpoints
        super.onAvailableCallEndpointsChanged(availableEndpoints)
    }
    @TargetApi(34)
    override fun onMuteStateChanged(isMuted: Boolean) {
        // api 34 uses this instead of onCallAudioStateChanged for mute state
        Log.d(debugTag, "mute state changed")
        super.onMuteStateChanged(isMuted)
    }

    override fun onStateChanged(state: Int) {
        Log.d( debugTag,
            "[Connection] Telecom state changed [${intStateToString(state)}] for call with id: $callId"
        )
        super.onStateChanged(state)
    }

    override fun onAnswer(videoState: Int) {
        Log.d( debugTag, "[Connection] Answering telecom call with id: $callId")
        getCall()?.accept() ?: selfDestroy()
    }

    override fun onHold() {
        Log.d( debugTag,"[Connection] Pausing telecom call with id: $callId")
        getCall()?.let { call ->
            if (call.conference != null) {
                call.conference?.leave()
            } else {
                call.pause()
            }
        } ?: selfDestroy()
        setOnHold()
    }

    override fun onUnhold() {
        Log.d( debugTag,"[Connection] Resuming telecom call with id: $callId")
        getCall()?.let { call ->
            if (call.conference != null) {
                call.conference?.enter()
            } else {
                call.resume()
            }
        } ?: selfDestroy()
        setActive()
    }

    @Deprecated("Deprecated in Java")
    override fun onCallAudioStateChanged(state: CallAudioState) {
        Log.d( debugTag,"Audio state changed: $state")

        val call = getCall()
        if (call != null) {
            if (getState() != STATE_ACTIVE && getState() != STATE_DIALING && getState() != STATE_RINGING) {
                Log.d( debugTag,
                    "[Connection] Call state isn't STATE_ACTIVE or STATE_DIALING, ignoring mute mic & audio route directive from TelecomManager"
                )
                return
            }

            if (state.isMuted != call.microphoneMuted) {
                Log.d( debugTag,
                    "[Connection] Connection audio state asks for changing in mute: ${state.isMuted}, currently is ${call.microphoneMuted}"
                )
                if (state.isMuted) {
                    Log.d( debugTag,"[Connection] Muting microphone")
                    call.microphoneMuted = true
                }
            }

            when (state.route) {
                CallAudioState.ROUTE_EARPIECE -> AudioRouteUtils.routeAudioToEarpiece(context, call, true)
                CallAudioState.ROUTE_SPEAKER -> AudioRouteUtils.routeAudioToSpeaker(context, call, true)
                CallAudioState.ROUTE_BLUETOOTH -> AudioRouteUtils.routeAudioToBluetooth(context, call, true)
                CallAudioState.ROUTE_WIRED_HEADSET -> AudioRouteUtils.routeAudioToHeadset(
                    context,
                    call,
                    true
                )
            }
        } else {
            selfDestroy()
        }
    }

    override fun onPlayDtmfTone(c: Char) {
        Log.d( debugTag,"[Connection] Sending DTMF [$c] in telecom call with id: $callId")
        getCall()?.sendDtmf(c) ?: selfDestroy()
    }

    override fun onDisconnect() {
        Log.d( debugTag,"[Connection] Terminating telecom call with id: $callId")
        getCall()?.terminate() ?: selfDestroy()
    }

    override fun onAbort() {
        Log.d( debugTag,"[Connection] Aborting telecom call with id: $callId")
        getCall()?.terminate() ?: selfDestroy()
    }

    override fun onReject() {
        Log.d( debugTag,"[Connection] Rejecting telecom call with id: $callId")
        getCall()?.terminate() ?: selfDestroy()
    }

    override fun onSilence() {
        Log.d( debugTag,"[Connection] Call with id: $callId asked to be silenced")
        FMCore.core.stopRinging()
    }

    fun stateAsString(): String {
        return stateToString(state)
    }

    private fun getCall(): Call? {
        return FMCore.core.getCallByCallid(callId)
    }

    private fun selfDestroy() {
        if (FMCore.core.callsNb == 0) {
            Log.d( debugTag,"[Connection] No call in Core, destroy connection")
            setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
            destroy()
        }
    }

    private fun intStateToString(state: Int): String {
        return when (state) {
            STATE_INITIALIZING -> "STATE_INITIALIZING"
            STATE_NEW -> "STATE_NEW"
            STATE_RINGING -> "STATE_RINGING"
            STATE_DIALING -> "STATE_DIALING"
            STATE_ACTIVE -> "STATE_ACTIVE"
            STATE_HOLDING -> "STATE_HOLDING"
            STATE_DISCONNECTED -> "STATE_DISCONNECTED"
            STATE_PULLING_CALL -> "STATE_PULLING_CALL"
            else -> "STATE_UNKNOWN"
        }
    }
}
