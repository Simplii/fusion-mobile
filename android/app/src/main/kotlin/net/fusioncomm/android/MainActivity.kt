package net.fusioncomm.android

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.PackageManager.FEATURE_TELEPHONY_SUBSCRIPTION
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.telephony.PhoneStateListener
import android.telephony.SubscriptionManager
import android.telephony.SubscriptionManager.DEFAULT_SUBSCRIPTION_ID
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import android.util.Log
import android.view.KeyEvent
import androidx.core.content.ContextCompat
import com.google.gson.Gson
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import net.fusioncomm.android.telecom.CallsManager
import org.linphone.core.*

class MainActivity : FlutterFragmentActivity() {
    private val core: Core = FMCore.core
    private val channel: MethodChannel = FusionMobileApplication.callingChannel
    private val versionName = BuildConfig.VERSION_NAME
    private var appOpenedFromBackground : Boolean = false
    private val callsManager: CallsManager = CallsManager.getInstance(this)
    private var myPhoneNumber:String = ""

    private lateinit var audioManager:AudioManager
    private lateinit var telephonyManager: TelephonyManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        // Create Contacts Provider Channel
        ContactsProvider(this)
        Log.d("MDBM ", "core started ${FMCore.coreStarted}")
        core.addListener(coreListener)
        checkPushIncomingCall()

        Log.d("MDBM ", "MainActivity on create")

        val incomingCallId : String? = intent.getStringExtra("payload")
        if(incomingCallId != null){
            appOpenedFromBackground = true
            intent.removeExtra("payload")
        }
    }

    override fun onResume() {
        super.onResume()
        val incomingCallId: String? = intent.getStringExtra("payload")
        if(!incomingCallId.isNullOrEmpty()){
            appOpenedFromBackground = true
            intent.removeExtra("payload")
        }
    }

    private  fun checkPushIncomingCall(){
        sendDevices()
        getAppVersion()
        getMyPhoneNumber()
        val activeCalls: Array<Call> = core.calls

        if(!activeCalls.isEmpty()){
            for (call in activeCalls){
                val uuid: String = callsManager.findUuidByCall(call)
                Log.d("MDBM CallState", "${Call.State.fromInt(call.state.ordinal)}")
                if(call.state == Call.State.IncomingReceived){
                    channel.invokeMethod(
                        "lnIncomingReceived",
                        mapOf(
                            Pair("uuid", uuid),
                            Pair("callId", call.callLog?.callId),
                            Pair("remoteContact", call.remoteContact),
                            Pair("remoteAddress", call.remoteAddressAsString),
                            Pair("displayName", call.remoteAddress.displayName)
                        )
                    )
                } else if( call.state == Call.State.StreamsRunning){
                    channel.invokeMethod(
                        "answeredFromNotification",
                        mapOf(
                            Pair("uuid", uuid),
                            Pair("callId", call.callLog?.callId),
                            Pair("remoteContact", call.remoteContact),
                            Pair("remoteAddress", call.remoteAddressAsString),
                            Pair("displayName", call.remoteAddress.displayName)
                        )
                    )
                } else if( call.state == Call.State.Paused){
                    channel.invokeMethod(
                        "answeredWhileOnCallFromNotification",
                        mapOf(
                            Pair("uuid", uuid),
                            Pair("callId", call.callLog?.callId),
                            Pair("remoteContact", call.remoteContact),
                            Pair("remoteAddress", call.remoteAddressAsString),
                            Pair("displayName", call.remoteAddress.displayName)
                        )
                    )
                }
            }
        }
    }

   override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
       if ((keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)){
           core.stopRinging()
       }
       return super.onKeyDown(keyCode, event)
   }

    private fun startFusionService(){
        if(!FusionService.serviceStarted){
            Log.d("fusionService","Start")
            Intent(this, FusionService::class.java).also { intent ->
                startService(intent)
            }
        } else {
            Log.d("fusionService","Service running")
        }
    }

    private val coreListener = object : CoreListenerStub() {
        override fun onAccountRegistrationStateChanged(
            core: Core,
            account: Account,
            state: RegistrationState,
            message: String
        ) {
            if (state == RegistrationState.Failed || state == RegistrationState.Cleared) {
                channel.invokeMethod(
                    "lnRegistrationFailed",
                    mapOf(Pair("registrationState", "failed"))
                )
            } else if (state == RegistrationState.Ok) {
                channel.invokeMethod(
                    "lnRegistrationSucceeded",
                    mapOf(Pair("registrationState", "success"))
                )
            }
        }

        override fun onAudioDeviceChanged(core: Core, audioDevice: AudioDevice) {
            // This listner will be triggered when switching audioDevice in call only
            val newDevice: Array<String> = arrayOf(audioDevice.id, audioDevice.type.name)

            if(newDevice.isNotEmpty()){

                val gson = Gson()

               channel.invokeMethod(
                        "lnAudioDeviceChanged",
                       mapOf(Pair("audioDevice", gson.toJson(newDevice)),
                            Pair("activeCallOutput", core.currentCall?.outputAudioDevice?.id),
                            Pair("defaultMic", core.defaultOutputAudioDevice.id))
                    )
           }

        }

        override fun onAudioDevicesListUpdated(core: Core) {
            // This callback will be triggered when the available devices list has changed,
            // for example after a bluetooth headset has been connected/disconnected.
            var devicesList: Array<Array<String>> = arrayOf()
            for (device in core.extendedAudioDevices) {
                devicesList = devicesList.plus(
                    arrayOf(device.deviceName, device.id, device.type.name)
                )
            }

            val gson = Gson()

            channel.invokeMethod(
                "lnAudioDeviceListUpdated",
                mapOf(Pair("devicesList", gson.toJson(devicesList)),
                    Pair("defaultInput", core.defaultInputAudioDevice.id),
                    Pair("defaultOutput", core.defaultOutputAudioDevice.id)))
            // sendDevices()
        }

        override fun onCallStateChanged(
            core: Core,
            call: Call,
            state: Call.State?,
            message: String
        ) {
            Log.d("MDBM", "callLogID  ${call.callLog.callId}")
            val uuid = callsManager.findUuidByCall(call)

            when (state) {
                Call.State.Idle -> {
                    channel.invokeMethod(
                        "lnIdle",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.IncomingReceived -> {
                    callsManager.incomingCall(
                        call.callLog.callId,
                        "8018976133",
                        FMUtils.getDisplayName(call.remoteAddress)
                    )
                    audioManager.mode = AudioManager.MODE_NORMAL
                    audioManager.isSpeakerphoneOn = true
                    channel.invokeMethod(
                        "lnIncomingReceived",
                        mapOf(
                            Pair("uuid", uuid),
                            Pair("callId", call.callLog.callId),
                            Pair("remoteContact", call.remoteContact),
                            Pair("remoteAddress", call.remoteAddressAsString),
                            Pair("displayName", call.remoteAddress.displayName)
                        )
                    )
                }
                Call.State.PushIncomingReceived -> {
                    audioManager.mode = AudioManager.MODE_NORMAL
                    audioManager.isSpeakerphoneOn = true
                    channel.invokeMethod(
                        "lnPushIncomingReceived",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.OutgoingInit -> {
                    // wait until .outgoingProgress to notify dart because the callid
                    // doesn't seem to be available during .OutgoingInit
                }
                Call.State.OutgoingProgress -> {
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    audioManager.isSpeakerphoneOn = false
                    CallsManager.uuidCalls[uuid] = call
                    channel.invokeMethod(
                        "lnOutgoingInit",
                        mapOf(
                            Pair("uuid", uuid),
                            Pair("callId", call.callLog.callId),
                            Pair("remoteAddress", call.remoteAddressAsString)
                        )
                    )
                    channel.invokeMethod(
                        "lnOutgoingProgress",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.OutgoingRinging -> {
                    channel.invokeMethod(
                        "lnOutgoingRinging",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.OutgoingEarlyMedia -> {
                    channel.invokeMethod(
                        "lnOutgoingEarlyMedia",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.Connected -> {
                    startFusionService()
                    channel.invokeMethod(
                        "lnConnected",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.StreamsRunning -> {
                    channel.invokeMethod(
                        "lnStreamsRunning",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.Pausing -> {
                    channel.invokeMethod(
                        "lnPausing",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.Paused -> {
                    channel.invokeMethod(
                        "lnPaused",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.Resuming -> {
                    channel.invokeMethod(
                        "lnResuming",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.Referred -> {
                    channel.invokeMethod(
                        "lnReferred",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.Error -> {
                    channel.invokeMethod(
                        "lnError",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.End -> {
                    audioManager.mode = AudioManager.MODE_NORMAL
                    audioManager.isSpeakerphoneOn = false
                    channel.invokeMethod(
                        "lnEnd",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.PausedByRemote -> {
                    channel.invokeMethod(
                        "lnPausedByRemote",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.UpdatedByRemote -> {
                    channel.invokeMethod(
                        "lnUpdatedByRemote",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.IncomingEarlyMedia -> {
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    channel.invokeMethod(
                        "lnIncomingEarlyMedia",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.Updating -> {
                    channel.invokeMethod(
                        "lnUpdating",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.Released -> {
                    if(appOpenedFromBackground){
                        appOpenedFromBackground= false
                        moveTaskToBack(true)
                    }
                    audioManager.mode = AudioManager.MODE_NORMAL
                    channel.invokeMethod(
                        "lnReleased",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.EarlyUpdatedByRemote -> {
                    channel.invokeMethod(
                        "lnEarlyUpdatedByRemote",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.EarlyUpdating -> {
                    channel.invokeMethod(
                        "lnEarlyUpdating",
                        mapOf(Pair("uuid", uuid))
                    )
                }

                else -> {}
            }
        }

    }

    private fun sendDevices() {
        var devicesList: Array<Array<String>> = arrayOf()
        for (device in core.extendedAudioDevices) {
            devicesList = devicesList.plus(
                arrayOf(device.deviceName, device.id, device.type.name)
            )
            if(device.type == AudioDevice.Type.Microphone && device.id.contains("openSLES")){
                core.defaultInputAudioDevice = device
            }

            if(device.type == AudioDevice.Type.Speaker && device.id.contains("openSLES")){
                core.defaultOutputAudioDevice = device
            }
        }

        val gson = Gson()
        channel.invokeMethod(
            "lnNewDevicesList",
            mapOf(Pair("devicesList", gson.toJson(devicesList)),
                Pair("echoLimiterEnabled", core.echoLimiterEnabled()),
                Pair("echoCancellationEnabled", core.echoCancellationEnabled()),
                Pair("echoCancellationFilterName", core.echoCancellerFilterName),
                Pair("defaultInput", core.defaultInputAudioDevice.id),
                Pair("defaultOutput", core.defaultOutputAudioDevice.id)))
    }

    private fun getAppVersion(){
        val gson = Gson()
        channel.invokeMethod("setAppVersion",  gson.toJson(versionName) )
    }

    private fun getMyPhoneNumber(){
        val gson = Gson()
        channel.invokeMethod("setMyPhoneNumber",  gson.toJson(myPhoneNumber) )
    }

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        GeneratedPluginRegistrant.registerWith(FusionMobileApplication.engine);
        return FusionMobileApplication.engine
    }
}