package net.fusioncomm.android

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.telephony.TelephonyManager
import android.util.Log
import android.view.KeyEvent
import com.google.gson.Gson
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import net.fusioncomm.android.FusionMobileApplication.Companion.engine
import net.fusioncomm.android.compatibility.Compatibility
import net.fusioncomm.android.notifications.NotificationsManager
import net.fusioncomm.android.telecom.AudioRouteUtils
import net.fusioncomm.android.telecom.CallQualityStream
import net.fusioncomm.android.telecom.CallsManager
import org.linphone.core.*

class MainActivity : FlutterActivity() {
    private val debugTag = "MDBM MainActivity"
    private val core: Core = FMCore.core
    private val channel: MethodChannel = FusionMobileApplication.callingChannel
    private val eventChannel: EventChannel = FusionMobileApplication.callEventChannel
    private var appOpenedFromBackground : Boolean = false
    private val callsManager: CallsManager = CallsManager.getInstance(this, channel)

    lateinit private var context:Context
    private lateinit var audioManager:AudioManager
    private lateinit var telephonyManager: TelephonyManager
    private val callInfoStream = CallQualityStream()

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            Compatibility.setShowWhenLocked(this, true)
            Compatibility.setTurnScreenOn(this, true)
            Compatibility.requestDismissKeyguard(this)
        }
        super.onCreate(savedInstanceState)
        context = this
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        // Create Contacts Provider Channel
        ContactsProvider(this)
        Log.d(debugTag, "core started ${FMCore.coreStarted}")
        core.addListener(coreListener)

        val incomingCallId : String? = intent.getStringExtra(NotificationsManager.INTENT_CALL_UUID)
        if(incomingCallId != null){
            appOpenedFromBackground = true
            intent.removeExtra("incomingCallUUID")
        }
        checkAnswerCallIntent()
        eventChannel.setStreamHandler(callInfoStream)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        checkAnswerCallIntent(intent)
    }

    override fun onDestroy() {
        for (call in core.calls) {
            call.terminate()
        }
        super.onDestroy()
    }
    override fun onResume() {
        super.onResume()
        checkPushIncomingCall()
        val incomingCallId: String? = intent.getStringExtra("payload")
        if(!incomingCallId.isNullOrEmpty()){
            appOpenedFromBackground = true
            intent.removeExtra("payload")
        }
    }

    private fun checkAnswerCallIntent(newIntent: Intent? = null) {
        val activityIntent = newIntent ?: intent
        val callUUID = activityIntent.getStringExtra(NotificationsManager.INTENT_CALL_UUID)
        val isAnswerCallAction = activityIntent.getBooleanExtra(
            NotificationsManager.INTENT_ANSWER_CALL_NOTIF_ACTION,
            false
        )
        Log.d(debugTag, "is answer call itente = $isAnswerCallAction calluuid = $callUUID" )
        if(isAnswerCallAction && callUUID != null ) {
            val call: Call? = FMCore.callsManager.findCallByUuid(callUUID)
            call?.accept()
        }
    }

    private  fun checkPushIncomingCall(){
        for (call in core.calls){
            val uuid: String = callsManager.findUuidByCall(call)

            Log.d(debugTag, "call state = ${Call.State.fromInt(call.state.ordinal)}")
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

   override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
       if ((keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)){
           core.stopRinging()
       }
       return super.onKeyDown(keyCode, event)
   }

    private val coreListener = object : CoreListenerStub() {
        override fun onLastCallEnded(core: Core) {
            Log.d("MDBM", "last call ended")
            super.onLastCallEnded(core)
        }

        override fun onAccountRegistrationStateChanged(
            core: Core,
            account: Account,
            state: RegistrationState,
            message: String
        ) {
            if (state == RegistrationState.Failed || state == RegistrationState.Cleared) {
                Log.d(debugTag, "Registration Failed error $message")
                channel.invokeMethod(
                    "lnRegistrationFailed",
                    mapOf(Pair("registrationState", "failed"))
                )
            } else if (state == RegistrationState.Ok) {
                Log.d(debugTag, "Registration Succeeded $message")
                channel.invokeMethod(
                    "lnRegistrationSucceeded",
                    mapOf(Pair("registrationState", "success"))
                )
            }
        }

        override fun onAudioDeviceChanged(core: Core, audioDevice: AudioDevice) {
            // This listner will be triggered when switching audioDevice in call only
            Log.d(debugTag, "onAudioDeviceChanged ${audioDevice.deviceName} ${audioDevice.type.name}")
            val device = hashMapOf(
                Pair("deviceDriverName", audioDevice.driverName),
                Pair("deviceId", audioDevice.id),
                Pair("deviceName", audioDevice.deviceName),
                Pair("deviceType", audioDevice.type.name),
            )
            channel.invokeMethod("lnAudioDeviceChanged", device)
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
        }

        override fun onCallStateChanged(
            core: Core,
            call: Call,
            state: Call.State?,
            message: String
        ) {
            Log.d(debugTag, "callLogID  ${call.callLog.callId}")
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
                        call.callLog.callId.orEmpty(),
                        FMUtils.getPhoneNumber(call.remoteAddress),
                        FMUtils.getDisplayName(call.remoteAddress)
                    )
//                    audioManager.mode = AudioManager.MODE_NORMAL
//                    audioManager.isSpeakerphoneOn = true
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
//                        moveTaskToBack(true)
                        finishAndRemoveTask()
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

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return engine
    }
}