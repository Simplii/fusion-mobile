package net.fusioncomm.android.telecom

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import net.fusioncomm.android.FMCore
import net.fusioncomm.android.FusionMobileApplication
import org.linphone.core.Call
import org.linphone.core.Core
import org.linphone.core.CoreListenerStub

class TelecomConnectionService : ConnectionService() {
    private val debugTag = "MDBM TelecomConnectionService"

    override fun onCreate() {
        super.onCreate()
        Log.d(debugTag, "onCreate()")
        FusionMobileApplication.ensureCoreExists(applicationContext)
        FMCore.core.addListener(listener)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        if (FusionMobileApplication.contextExists()) {
            Log.d(debugTag, "onUnbind()")
            FMCore.core.removeListener(listener)
        }
        return super.onUnbind(intent)
    }


    override fun onCreateOutgoingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d(debugTag, "onCreateOutgoingConnection")
        if (FMCore.core.callsNb == 0) {
            Log.d(debugTag,"No call in Core, aborting outgoing connection!")
            return Connection.createCanceledConnection()
        }

        val accountHandle = request?.accountHandle
        val componentName = ComponentName(applicationContext, this.javaClass)
        return if (accountHandle != null && componentName == accountHandle.componentName && request != null) {
            makeOutgoingCall(request)
        } else {
            Log.d(debugTag,"Error: $accountHandle $componentName")
            Connection.createFailedConnection(
                DisconnectCause(
                    DisconnectCause.ERROR,
                    "Invalid inputs: $accountHandle $componentName"
                )
            )

        }

    }

    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ): Connection {
        Log.d(debugTag, "onCreateIncomingConnection $request ${request?.address}")
        if (FMCore.core.callsNb == 0) {
            Log.d(debugTag,"No call in Core, aborting outgoing connection! ")
            return Connection.createCanceledConnection()
        }
        val accountHandle = request?.accountHandle
        val componentName = ComponentName(applicationContext, this.javaClass)
        return if (accountHandle != null && componentName == accountHandle.componentName && request != null) {
            makeIncomingConnection(request)
        } else {
            Log.d(debugTag,"Error: $accountHandle $componentName")
            Connection.createFailedConnection(
                DisconnectCause(
                    DisconnectCause.ERROR,
                    "Invalid inputs: $accountHandle $componentName"
                )
            )

        }

    }

    private fun makeOutgoingCall(request: ConnectionRequest): Connection {
        val extras: Bundle = request.extras
        val number: String = request?.address?.schemeSpecificPart ?: "Unknown"
//        val extrasNumber: String = extras.getString(CallsManager.EXTRA_CALL_NUMBER) ?: "Unknown"
        val displayName:String = extras.getString(CallsManager.EXTRA_CALLER_NAME) ?: number
        var callId = extras.getString(CallsManager.EXTRA_CALL_UUID)

        Log.d(debugTag, "Creating outgoing connection callid:$callId, number: $number, displayName:$displayName")

        if (callId == null) {
            callId = FMCore.core.currentCall?.callLog?.callId ?: ""
        }
        Log.d( debugTag,
            "Outgoing connection is for call [$callId] with display name [$displayName]"
        )

        // Prevents user dialing back from native dialer app history
        if (callId.isEmpty() && displayName.isEmpty()) {
            Log.d(debugTag,
                "Looks like a call was made from native dialer history, aborting"
            )
            return Connection.createFailedConnection(DisconnectCause(DisconnectCause.OTHER))
        }

        val connection = NativeCallWrapper(callId)
        val call = FMCore.core.calls.find { it.callLog.callId == callId }
        if (call != null) {
            val callState = call.state
            Log.d(
                debugTag,
                "Found outgoing call from ID [$callId] with state [$callState]"
            )
            when (callState) {
                Call.State.OutgoingEarlyMedia, Call.State.OutgoingInit, Call.State.OutgoingProgress, Call.State.OutgoingRinging -> connection.setDialing()
                Call.State.Paused, Call.State.PausedByRemote, Call.State.Pausing -> connection.setOnHold()
                Call.State.End, Call.State.Error, Call.State.Released -> connection.setDisconnected(
                    DisconnectCause(DisconnectCause.ERROR)
                )
                else -> connection.setActive()
            }
        } else {
            Log.d(
                debugTag,
                "Outgoing call not found for cal ID [$callId], assuming it's state is dialing"
            )
            connection.setDialing()
        }

        val providedHandle = request.address
        connection.setAddress(providedHandle, TelecomManager.PRESENTATION_ALLOWED)
        connection.setCallerDisplayName(displayName, TelecomManager.PRESENTATION_ALLOWED)
        Log.d( debugTag,"Address is $providedHandle")

        CallsManager.connections.add(connection)
        return  connection
    }

    private fun makeIncomingConnection(request: ConnectionRequest?): Connection {
        val extras: Bundle = request!!.extras
        val number: String = request?.address?.schemeSpecificPart ?: "Unknown"
        val displayName: String = extras.getString(CallsManager.EXTRA_CALLER_NAME) ?: number
        var callId = extras.getString(CallsManager.EXTRA_CALL_UUID)

        Log.d(debugTag, "makeOutgoingCall:$callId, number: $number, displayName:$displayName")

        Log.d(debugTag, "Creating incoming connection")
//        val incomingExtras = extras.getBundle(TelecomManager.EXTRA_INCOMING_CALL_EXTRAS)

        if (callId == null) {
            callId = FMCore.core.currentCall?.callLog?.callId ?: ""
        }
        Log.d(
            debugTag,
            "Incoming connection is for call [$callId] with display name [$displayName]"
        )

        val connection = NativeCallWrapper(callId)
        val call = FMCore.core.calls.find { it.callLog.callId == callId }
        if (call != null) {
            val callState = call.state
            Log.d(
                debugTag,
                "Found incoming call from ID [$callId] with state [$callState]"
            )
            when (callState) {
                Call.State.IncomingEarlyMedia, Call.State.IncomingReceived -> connection.setRinging()
                Call.State.Paused, Call.State.PausedByRemote, Call.State.Pausing -> connection.setOnHold()
                Call.State.End, Call.State.Error, Call.State.Released -> connection.setDisconnected(
                    DisconnectCause(DisconnectCause.ERROR)
                )

                else -> connection.setActive()
            }

        } else {
            Log.d(
                debugTag,
                "Incoming call not found for cal ID [$callId], assuming it's state is ringing"
            )
            connection.setRinging()
        }

//        val providedHandle =
//            incomingExtras?.getParcelable<Uri>(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS)
//        connection.setAddress(providedHandle, TelecomManager.PRESENTATION_ALLOWED)
        connection.setCallerDisplayName(displayName, TelecomManager.PRESENTATION_ALLOWED)
        Log.d(debugTag,"display name is  is $displayName")

        CallsManager.connections.add(connection)
        return connection
    }



    override fun onCreateOutgoingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        // method to inform your app that the call cannot be placed at the current time.
        // FM should inform the user that the call cannot be placed.
        super.onCreateOutgoingConnectionFailed(connectionManagerPhoneAccount, request)
        Log.d(debugTag, "Call can't be placed at this time")
    }

    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?
    ) {
        super.onCreateIncomingConnectionFailed(connectionManagerPhoneAccount, request)
    }

    private val listener: CoreListenerStub = object : CoreListenerStub() {
        override fun onCallStateChanged(
            core: Core,
            call: Call,
            state: Call.State?,
            message: String
        ) {
            Log.d(
                debugTag,
                "call [${call.callLog.callId}] state changed: $state"
            )
            when (call.state) {
                Call.State.OutgoingProgress -> {
                    for (connection in CallsManager.connections) {
                        if (connection.callId.isEmpty()) {
                            Log.d(
                                debugTag,
                                "Updating connection with call ID: ${call.callLog.callId}"
                            )
                            connection.callId = core.currentCall?.callLog?.callId ?: ""
                        }
                    }
                }
                Call.State.Error -> onCallError(call)
                Call.State.End, Call.State.Released -> onCallEnded(call)
                Call.State.Paused, Call.State.Pausing, Call.State.PausedByRemote -> onCallPaused(
                    call
                )
                Call.State.Connected, Call.State.StreamsRunning -> onCallConnected(call)
                else -> {}
            }
        }

        override fun onLastCallEnded(core: Core) {
            val connectionsCount = CallsManager.connections.size
            if (connectionsCount > 0) {
                Log.d(
                    debugTag,
                    "Last call ended, there is $connectionsCount connections still alive"
                )
                for (connection in CallsManager.connections) {
                    Log.d(
                        debugTag,
                        "Destroying zombie connection ${connection.callId}"
                    )
                    connection.setDisconnected(DisconnectCause(DisconnectCause.OTHER))
                    connection.destroy()
                }
            }
        }
    }

    private fun onCallError(call: Call) {
        val callId = call.callLog.callId
        val connection = CallsManager.findConnectionForCallId(callId.orEmpty())
        if (connection == null) {
            Log.d( debugTag,"Call Error Failed to find connection for call id: $callId")
            return
        }

        CallsManager.connections.remove(connection)
        Log.d(
            debugTag,"Call [$callId] is in error, destroying connection currently in ${connection.stateAsString()}"
        )
        connection.setDisconnected(DisconnectCause(DisconnectCause.ERROR))
        connection.destroy()
    }

    private fun onCallEnded(call: Call) {
        val callId = call.callLog.callId
        val connection = CallsManager.findConnectionForCallId(callId.orEmpty())
        if (connection == null) {
            Log.d(debugTag,"Call Ended Failed to find connection for call id: $callId")
            return
        }

        CallsManager.connections.remove(connection)
        val reason = call.reason
        Log.d(
            debugTag,
            "Call [$callId] ended with reason: $reason, destroying connection currently in ${connection.stateAsString()}"
        )
        connection.setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        connection.destroy()
    }

    private fun onCallPaused(call: Call) {
        val callId = call.callLog.callId
        val connection = CallsManager.findConnectionForCallId(callId.orEmpty())
        if (connection == null) {
            Log.d( debugTag,"Call Hold Failed to find connection for call id: $callId")
            return
        }
        Log.d(
            debugTag,
            "Setting connection as on hold, currently in ${connection.stateAsString()}"
        )
        connection.setOnHold()
    }

    private fun onCallConnected(call: Call) {
        val callId = call.callLog.callId
        val connection = CallsManager.findConnectionForCallId(callId.orEmpty())
        if (connection == null) {
            Log.d(debugTag,"Call Connected Failed to find connection for call id: $callId")
            return
        }

        Log.d(
            debugTag,"Setting connection as active, currently in ${connection.stateAsString()}"
        )
        connection.setActive()
    }

}