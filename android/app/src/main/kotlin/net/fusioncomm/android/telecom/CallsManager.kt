package net.fusioncomm.android.telecom

import android.Manifest
import android.annotation.SuppressLint
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import net.fusioncomm.android.FMCore
import net.fusioncomm.android.FMUtils
import net.fusioncomm.android.notifications.NotificationsManager
import net.fusioncomm.android.services.FusionCallService
import org.linphone.core.Call
import org.linphone.core.CallParams
import org.linphone.core.Conference
import org.linphone.core.Core
import org.linphone.core.MediaEncryption
import java.math.BigInteger
import java.security.MessageDigest

class CallsManager(private val context: Context) {
    private val debugTag = "MDBM CallsManager"
    val telecomManager: TelecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
    private val core: Core = FMCore.core
    private val phoneAccount:PhoneAccount
    private val phoneAccountHandle: PhoneAccountHandle
    private var conferenceStarting: Boolean = false
    init {
        val cName = ComponentName(context, TelecomConnectionService::class.java)
        val appName: String = FMCore.getApplicationName(context)
        phoneAccountHandle = PhoneAccountHandle(cName, appName)
        val builder: PhoneAccount.Builder =
            PhoneAccount.builder(phoneAccountHandle,appName)
                .setCapabilities(PhoneAccount.CAPABILITY_SELF_MANAGED)
        phoneAccount = builder.build()
        Log.d(debugTag,"Phone account created $phoneAccount")
        telecomManager.registerPhoneAccount(phoneAccount)
        Log.d(debugTag,"Phone account registerd with telecom")
    }

    companion object {
        @SuppressLint("StaticFieldLeak")
        @Volatile private var instance: CallsManager? = null // Volatile modifier is necessary
        fun getInstance(context: Context) = instance ?: synchronized(this) {
            // synchronized to avoid concurrency problem
            instance ?: CallsManager(context).also { instance = it }
        }

        const val EXTRA_CALLER_NAME = "EXTRA_CALLER_NAME"
        const val EXTRA_CALL_UUID = "EXTRA_CALL_UUID"
        const val EXTRA_CALL_NUMBER = "EXTRA_CALL_NUMBER"
        var uuidCalls: MutableMap<String, Call> = mutableMapOf()
        val connections = arrayListOf<NativeCallWrapper>()

        fun findConnectionForCallId(callId: String): NativeCallWrapper? {
            return connections.find { connection ->
                connection.callId == callId
            }
        }

    }

    fun outgoingCall(destination: String) {
        val remoteAddress = core.interpretUrl(destination)
        val params: CallParams? = core.createCallParams(null)
        if (remoteAddress != null && params != null) {
            params.mediaEncryption = MediaEncryption.None
            params.enableVideo(false)
            core.inviteAddressWithParams(remoteAddress, params)
            placeOutgoingCall(destination)
        }
    }

    fun incomingCall (callId: String, number: String, callerName:String) {
        Log.d(debugTag, "report incoming to telecom callid = $callId")
        val extras = Bundle()
        val uri = Uri.fromParts(PhoneAccount.SCHEME_TEL,number,null)
        extras.putParcelable(TelecomManager.EXTRA_INCOMING_CALL_ADDRESS, uri)
        extras.putString(EXTRA_CALLER_NAME, callerName)
        extras.putString(EXTRA_CALL_UUID, callId)
        Log.d(debugTag, "report incoming to telecom callid = $callId callerName = $callerName ")

        telecomManager.addNewIncomingCall(phoneAccountHandle, extras)
    }

    fun startConference() {
        if (conferenceStarting) return
        conferenceStarting = true
        if(core.conference == null){
            val params = core.createConferenceParams()
            params.isVideoEnabled = true
            val conference: Conference? = core.createConferenceWithParams(params)
            conference?.addParticipants(core.calls)
        } else {
            for (call in core.calls) {
                if (call.conference == null) {
                    core.conference?.addParticipant(call)
                }
            }
            if (!core.conference!!.isIn) {
                Log.d(debugTag,"[Conference] Conference was paused, resuming it")
                core.conference!!.enter()
            }
        }
        conferenceStarting = false
    }

    fun findCallByUuid(uuid: String): Call? {
        return uuidCalls[uuid]
    }

    private fun placeOutgoingCall (dest:String) {
        Log.d(debugTag, "report outgoing to telecom callid = ${FMCore.core.currentCall?.callLog?.callId}")

        val uri = Uri.fromParts(PhoneAccount.SCHEME_TEL, dest, null)

        val extras = Bundle()
        val callExtras = Bundle()
        callExtras.putString(EXTRA_CALLER_NAME, "test caller")
        callExtras.putString(EXTRA_CALL_UUID, FMCore.core.currentCall?.callLog?.callId)
        callExtras.putString(EXTRA_CALL_NUMBER, dest)

        extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, phoneAccountHandle)
        extras.putParcelable(TelecomManager.EXTRA_OUTGOING_CALL_EXTRAS, callExtras)

        if (ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.CALL_PHONE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            Log.d(debugTag, "missing permission")
            return
        }
        telecomManager.placeCall(uri, extras)
        Log.d(debugTag, "call placed in telecom")
    }

    fun findUuidByCall(call: Call): String {
        val callId = call.callLog.callId.orEmpty()
        if(callId.isEmpty()) return ""

        val md = MessageDigest.getInstance("MD5")
        val md5 = BigInteger(1, md.digest(callId.toByteArray()))
            .toString(16)
            .padStart(32, '0')
        var numbers: Array<String> = arrayOf()

        for (i in 0..15) {
            numbers = numbers.plusElement(md5[i].code.toString(16))
        }

        var r: String = numbers[0] + numbers[1] + numbers[2] + numbers[3] + "-"
        r += numbers[4] + numbers[5] + "-"
        r += numbers[6] + numbers[7] + "-"
        r += numbers[8] + numbers[9] + "-"
        r += numbers[10] + numbers[11] + numbers[12] + numbers[13] + numbers[14] + numbers[15]

        uuidCalls.put(r, call)
        return r
    }


}