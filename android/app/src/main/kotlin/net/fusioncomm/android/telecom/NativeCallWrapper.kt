package net.fusioncomm.android.telecom

import android.telecom.CallAudioState
import android.telecom.CallEndpoint
import android.telecom.Connection
import android.telecom.DisconnectCause
import net.fusioncomm.android.FMCore
import org.linphone.core.Call
import org.linphone.core.tools.Log


class NativeCallWrapper(var callId: String) : Connection() {
    private val debugTag = "MDBM CallWrapper"
    init {
        val properties = connectionProperties or PROPERTY_SELF_MANAGED
        connectionProperties = properties

        val capabilities = connectionCapabilities or CAPABILITY_MUTE or CAPABILITY_SUPPORT_HOLD or CAPABILITY_HOLD
        connectionCapabilities = capabilities

        audioModeIsVoip = true
    }

    // api 34 uses this instead of onCallAudioStateChanged
    override fun onCallEndpointChanged(callEndpoint: CallEndpoint) {
        super.onCallEndpointChanged(callEndpoint)
        Log.d(debugTag, "Call endpoint changed")
    }
    // api 34 uses this instead of onCallAudioStateChanged for new list of devices
    override fun onAvailableCallEndpointsChanged(availableEndpoints: MutableList<CallEndpoint>) {
        super.onAvailableCallEndpointsChanged(availableEndpoints)
        Log.d(debugTag, "new Call endpoints available")

    }
    // api 34 uses this instead of onCallAudioStateChanged for mute state
    override fun onMuteStateChanged(isMuted: Boolean) {
        super.onMuteStateChanged(isMuted)
        Log.d(debugTag, "mute state changed")
    }

    override fun onStateChanged(state: Int) {
        Log.i(
            "[Connection] Telecom state changed [${intStateToString(state)}] for call with id: $callId"
        )
        super.onStateChanged(state)
    }

    override fun onAnswer(videoState: Int) {
        Log.i("[Connection] Answering telecom call with id: $callId")
        getCall()?.accept() ?: selfDestroy()
    }

    override fun onHold() {
        Log.i("[Connection] Pausing telecom call with id: $callId")
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
        Log.i("[Connection] Resuming telecom call with id: $callId")
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
        Log.i("[Connection] Audio state changed: $state")

        val call = getCall()
        if (call != null) {
            if (getState() != STATE_ACTIVE && getState() != STATE_DIALING) {
                Log.w(
                    "[Connection] Call state isn't STATE_ACTIVE or STATE_DIALING, ignoring mute mic & audio route directive from TelecomManager"
                )
                return
            }

            if (state.isMuted != call.microphoneMuted) {
                Log.w(
                    "[Connection] Connection audio state asks for changing in mute: ${state.isMuted}, currently is ${call.microphoneMuted}"
                )
                if (state.isMuted) {
                    Log.w("[Connection] Muting microphone")
                    call.microphoneMuted = true
                }
            }

            when (state.route) {
                CallAudioState.ROUTE_EARPIECE -> AudioRouteUtils.routeAudioToEarpiece(call, true)
                CallAudioState.ROUTE_SPEAKER -> AudioRouteUtils.routeAudioToSpeaker(call, true)
                CallAudioState.ROUTE_BLUETOOTH -> AudioRouteUtils.routeAudioToBluetooth(call, true)
                CallAudioState.ROUTE_WIRED_HEADSET -> AudioRouteUtils.routeAudioToHeadset(
                    call,
                    true
                )
            }
        } else {
            selfDestroy()
        }
    }

    override fun onPlayDtmfTone(c: Char) {
        Log.i("[Connection] Sending DTMF [$c] in telecom call with id: $callId")
        getCall()?.sendDtmf(c) ?: selfDestroy()
    }

    override fun onDisconnect() {
        Log.i("[Connection] Terminating telecom call with id: $callId")
        getCall()?.terminate() ?: selfDestroy()
    }

    override fun onAbort() {
        Log.i("[Connection] Aborting telecom call with id: $callId")
        getCall()?.terminate() ?: selfDestroy()
    }

    override fun onReject() {
        Log.i("[Connection] Rejecting telecom call with id: $callId")
        getCall()?.terminate() ?: selfDestroy()
    }

    override fun onSilence() {
        Log.i("[Connection] Call with id: $callId asked to be silenced")
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
            Log.e("[Connection] No call in Core, destroy connection")
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
