@file:Suppress("DEPRECATION")

package net.fusioncomm.android

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.getSystemService
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.firebase.Firebase
import com.google.firebase.crashlytics.FirebaseCrashlytics
import com.google.firebase.crashlytics.crashlytics
import com.google.gson.Gson
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import net.fusioncomm.android.notifications.NotificationsManager
import net.fusioncomm.android.telecom.AudioRouteUtils
import net.fusioncomm.android.telecom.CallsManager
import org.linphone.core.AVPFMode
import org.linphone.core.AudioDevice
import org.linphone.core.AuthInfo
import org.linphone.core.Core
import org.linphone.core.Factory
import org.linphone.core.ProxyConfig
import org.linphone.core.TransportType


class FMCore(private val context: Context, private val channel:MethodChannel): LifecycleOwner {

    private val _lifecycleRegistry = LifecycleRegistry(this)
    override val lifecycle: Lifecycle
        get() = _lifecycleRegistry

    private val factory: Factory = Factory.instance()
    private val server: String = "services.fusioncomm.net"
    private val audioManager:AudioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    private val telephonySubscriptionManager: SubscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
    private val sharedPref:SharedPreferences = context.getSharedPreferences(
        "net.fusioncomm.android.fusionValues",
        Context.MODE_PRIVATE
    )
    private var crashlytics: FirebaseCrashlytics
    companion object{
        private const val debugTag = "MDBM FMCore"
        lateinit var core:Core
        var coreStarted: Boolean = false
        lateinit var callsManager: CallsManager
        lateinit var notificationsManager: NotificationsManager

        fun getApplicationName(appContext: Context): String {
            val applicationInfo = appContext.applicationInfo
            val stringId = applicationInfo.labelRes
            return if (stringId == 0) applicationInfo.nonLocalizedLabel.toString()
                else "Fusion Mobile"
        }
    }


    init {
        _lifecycleRegistry.currentState = Lifecycle.State.INITIALIZED
        Log.d(debugTag, "Init ${this.lifecycle.currentState}")
        crashlytics = Firebase.crashlytics
        crashlytics.setUserId("123456789")

        setupCore()
        setFlutterActionsHandler()
        val started: Int = core.start()
        coreStarted = started == 0
        if (coreStarted) {
            _lifecycleRegistry.currentState = Lifecycle.State.STARTED
        }
        val username: String? = sharedPref.getString("username", "")
        val domain:String? = sharedPref.getString("domain", "")
        val password:String? = sharedPref.getString("password", "")
        if(!username.isNullOrEmpty() && !password.isNullOrEmpty() && !domain.isNullOrEmpty() ){
            register(username, password, domain)
        }
        callsManager = CallsManager.getInstance(context, channel)
        notificationsManager = NotificationsManager(context, callsManager)
        notificationsManager.onCoreReady()
        Log.d(debugTag, "started ${this.lifecycle.currentState}")
    }

    private fun setupCore() {
        Log.d(debugTag, "setup core")
        core = factory.createCore(null, null, context)
        factory.setDebugMode(true, "FM")
        core.enableIpv6(false)
        core.stunServer = "turn:$server"
        core.natPolicy?.stunServerUsername = "fuser"
        core.addAuthInfo(
            factory.createAuthInfo(
                "fuser",
                "fuser",
                "fpassword",
                null,
                null,
                null
            )
        )
        core.natPolicy?.enableTurn(true)
        core.enableEchoLimiter(true)
        core.enableEchoCancellation(true)

        if (core.hasBuiltinEchoCanceller()) {
            print("Device has built in echo canceler, disabling software echo canceler")
            core.enableEchoCancellation(false)
        } else {
            print("Device has no echo canceler, enabling software echo canceler")
            core.enableEchoCancellation(true)
        }

        core.natPolicy?.stunServer = server
        core.remoteRingbackTone = "android.resource://net.fusioncomm.android/" + R.raw.outgoing
        val ringtonePath: Uri? =
            RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
        if (ringtonePath != null) {
            core.ring =
                RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
                    .toString()
        } else {
            core.isNativeRingingEnabled = true
        }
        core.config.setBool("audio", "android_pause_calls_when_audio_focus_lost", false)
        _lifecycleRegistry.currentState = Lifecycle.State.CREATED
        for ( audioType in core.audioPayloadTypes){
            Log.d(debugTag, "codec ${audioType.mimeType}")

        }
    }

    private fun unregister() {
        val account = core.defaultAccount
        account ?: return
        val params = account.params
        val clonedParams = params.clone()

        clonedParams.registerEnabled = false

        account.params = clonedParams
        sharedPref.edit().clear().commit()
//        finishAndRemoveTask()
    }

    private fun setFlutterActionsHandler() {
        channel.setMethodCallHandler { call, results ->
            if (call.method == "setSpeaker") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val devices = audioManager.availableCommunicationDevices
                    for (device in devices) {
                        if (device.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                            Log.d("TAG", "setspeakernew")
                            audioManager.setCommunicationDevice(device)
                        }
                    }
                } else {
                    audioManager.isSpeakerphoneOn = true
                }
            } else if (call.method == "setEarpiece") {
                audioManager.isSpeakerphoneOn = false
            } else if (call.method == "lpAnswer") {
                val args = call.arguments as List<*>
                val lpCall = callsManager.findCallByUuid(args[0] as String)
                Log.d(debugTag, "LpAnswer")
                lpCall?.accept()
            } else if (call.method == "lpSendDtmf") {
                val args = call.arguments as List<*>
                val lpCall = callsManager.findCallByUuid(args[0] as String)
                lpCall?.sendDtmfs(args[1] as String)
            } else if (call.method == "lpSetHold") {
                val args = call.arguments as List<*>
                val lpCall = callsManager.findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    if (!(args[1] as Boolean)) {
                        lpCall.resume()
                    } else {
                        lpCall.pause()
                    }
                }
            } else if (call.method == "setUnhold") {
                //this was missing not sure if it's needed
//                val args = call.arguments as List<*>
//                val lpCall = callsManager.findCallByUuid(args[0] as String)
//                lpCall?.resume()
                Log.d(debugTag, "setUnhold")
            } else if (call.method == "lpSetEchoCancellationEnabled") {
                val args = call.arguments as List<*>
                core.enableEchoCancellation(args[0] as Boolean)
            } else if (call.method == "lpCalibrateEcho") {
                core.startEchoCancellerCalibration()
            } else if (call.method == "lpTestEcho") {
                core.startEchoTester(10)
            } else if (call.method == "lpStopTestEcho") {
                core.stopEchoTester()
            }
            else if (call.method == "lpSetDefaultInput") {
                val args = call.arguments as List<*>
                Log.d("setinput", "gonna set default input")
                for (audioDevice in core.extendedAudioDevices) {
                    Log.d("setinput", "checking audio device" + audioDevice.id)
                    Log.d("setinput", "checking against" + args[0])
                    if (audioDevice.id == args[0]) {
                        Log.d("setinput", "found the default input")
                        core.defaultInputAudioDevice = audioDevice
                        for  (coreCall in core.calls) {
                            Log.d("setinput", "setting the default input for a call")
                            coreCall.inputAudioDevice = audioDevice
                            Log.d("setinput", audioDevice.id)
                        }
                    }
                }
//                 sendDevices()
            } else if (call.method == "lpSetDefaultOutput") {
                val args = call.arguments as List<*>
                for (audioDevice in core.extendedAudioDevices) {
                    Log.d("setou8tput", "out checking audio device" + audioDevice.id)
                    Log.d("output", "out checking against" + args[0])

                    if (audioDevice.id == args[0]) {
                        core.defaultOutputAudioDevice = audioDevice
                        for  (coreCall in core.calls) {
                            Log.d("setinput", "setting the default input for a call")

                            coreCall.outputAudioDevice = audioDevice
                        }
                    }
                }
//                 sendDevices()
            } else if(call.method == "lpSetActiveCallOutput") {
//                val args = call.arguments as List<*>
//                Log.d(debugTag, "lpSetActiveCallOutput ${args[0]}")
//                for (audioDevice in core.audioDevices) {
//                    if (audioDevice.id == args[0]) {
//                        Log.d("lpSetActiveCallOutput", "args" +args[0])
//                        Log.d("lpSetActiveCallOutput", "audio device" +audioDevice.id)
//
//                        core.currentCall?.outputAudioDevice = audioDevice
//                    }
//                }
            }
            else if (call.method == "toggleSpeaker") {
                val args = call.arguments as List<*>
                var useSpeaker: Any? = args.first()
                val isBluetoothUsed = AudioRouteUtils.isBluetoothAudioRouteCurrentlyUsed()
                val isSpeakerUsed = AudioRouteUtils.isSpeakerAudioRouteCurrentlyUsed()

                if (useSpeaker == true) {
                    //force speaker route
                    AudioRouteUtils.routeAudioToSpeaker(context)
                }

                if (useSpeaker == false) {
                    if (isBluetoothUsed || isSpeakerUsed) {
                        // route to earpiece
                        AudioRouteUtils.routeAudioToEarpiece(context)
                    }
                }

            } else if (call.method == "lpSetBluetooth"){
                Log.d(debugTag, "lpSetBluetooth triggered")
                AudioRouteUtils.routeAudioToBluetooth(context)
            } else if (call.method == "lpMuteCall") {
                val args = call.arguments as List<*>
                val lpCall = callsManager.findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    lpCall.microphoneMuted = true
                }
            } else if (call.method == "lpUnmuteCall") {
                val args = call.arguments as List<*>
                val lpCall = callsManager.findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    lpCall.microphoneMuted = false
                }
            } else if (call.method == "lpRefer") {
                val args = call.arguments as List<*>
                val lpCall = callsManager.findCallByUuid(args[0] as String)
                lpCall?.transfer(args[1] as String)
            } else if (call.method == "lpStartCall") {
                val args = call.arguments as List<*>
                callsManager.outgoingCall(args[0] as String)
//                outgoingCall(args[0] as String)
            } else if (call.method == "lpEndCall") {
                val args = call.arguments as List<*>
                val lpCall = callsManager.findCallByUuid(args[0] as String)
                lpCall?.terminate()
            } else if (call.method == "lpEndConference") {
                if(core.conference?.isIn == true){
                    core.terminateConference()
                }
            } else if (call.method == "lpAssistedTransfer") {
                val args = call.arguments as List<*>
                val lpCallToTransfer = callsManager.findCallByUuid(args[0] as String)
                val activeCall = callsManager.findCallByUuid(args[1] as String)

                if(lpCallToTransfer != null && activeCall != null){
                    lpCallToTransfer.transferToAnother(activeCall)
                }

            } else if (call.method == "start3Way") {
                callsManager.startConference()
            } else if (call.method == "lpRegister") {
                val args = call.arguments as List<*>
                val username = args[0] as String
                val password = args[1] as String
                val domain = args[2] as String

                if (sharedPref.getString("username", null) == null ||
                    sharedPref.getString("password", null) == null ||
                    sharedPref.getString("domain", null) == null) {

                    with (sharedPref.edit()) {
                        putString("username", username)
                        putString("password", password)
                        putString("domain", domain)
                        apply()
                    }
                    // first time user registration
                    register(username,password,domain)
                } else {
                    // returned user
                    Log.d(debugTag, "Linphone should be registered from sharedpref")
                }
                sendDevices()
                val gson = Gson()
                channel.invokeMethod(
                    "setAppVersion",
                    gson.toJson("1.2.29")
                )
                var myPhoneNumber = ""

                if (ActivityCompat.checkSelfPermission(
                        context,
                        Manifest.permission.READ_SMS
                    ) != PackageManager.PERMISSION_GRANTED && ActivityCompat.checkSelfPermission(
                        context,
                        Manifest.permission.READ_PHONE_NUMBERS
                    ) != PackageManager.PERMISSION_GRANTED && ActivityCompat.checkSelfPermission(
                        context,
                        Manifest.permission.READ_PHONE_STATE
                    ) != PackageManager.PERMISSION_GRANTED
                ) {
                    // TODO: Consider calling
                    //    ActivityCompat#requestPermissions
                }
                if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    myPhoneNumber = telephonySubscriptionManager.getPhoneNumber(
                        SubscriptionManager.DEFAULT_SUBSCRIPTION_ID
                    )
                } else {
                    myPhoneNumber = telephonyManager.line1Number
                }
                channel.invokeMethod("setMyPhoneNumber",  gson.toJson(myPhoneNumber) )
            } else if (call.method == "lpUnregister") {
                //this is not being hit from flutter
                Log.d(debugTag, "lpUnregister")
                unregister()
            }
            else if (call.method == "crashTest") {
                //this is not being hit from flutter
                val args = call.arguments as List<*>

//                try {
//                    throw RuntimeException("test crash")
//                } catch (ex: RuntimeException) {
//                    // [START crashlytics_log_and_report]
//                    crashlytics.log("RTE caught!")
//                    crashlytics.recordException(ex)
//                    // [END crashlytics_log_and_report]
//                }
                Log.d(debugTag,"ttt $args")

            }
            else if (call.method == "testANR") {
                //this is not being hit from flutter
                val args = call.arguments as List<*>
                Thread.sleep(9000)
                Log.d(debugTag,"ttt $args")

            } else {
                Log.d(debugTag,"setFlutterActionHandler call = ${call.method}")
                results.notImplemented()
            }
        }
    }

    private fun register(
        username:String,
        password:String,
        domain:String,
    ) {
        Log.d(debugTag, "LPRegister FMCOre $username $password $domain ")
        val transportType = TransportType.Tls
        val authInfo =
            factory.createAuthInfo(
                username,
                null,
                password,
                null,
                null,
                domain,
                null
            )
        val accountParams = core.createAccountParams()
        val identity = Factory.instance().createAddress("sip:$username@$domain")
        accountParams.identityAddress = identity

        val address = Factory.instance().createAddress("sip:${server}:5061")
        address?.transport = transportType
        accountParams.serverAddress = address
        accountParams.registerEnabled = true
        accountParams.setRoutesAddresses(arrayOf(address))
        accountParams.avpfMode = AVPFMode.Disabled
        accountParams.dialEscapePlusEnabled = false
        accountParams.publishEnabled = false
        accountParams.identityAddress = core.createAddress("sip:$username@$domain")

        val account = core.createAccount(accountParams)

        core.addAuthInfo(authInfo)
        core.addAccount(account)
        core.loadConfigFromXml("android.resource://net.fusioncomm.net/" + R.raw.fusion_config)

        var proxyConfig = core.defaultProxyConfig
        if (proxyConfig == null) {
            proxyConfig = core.createProxyConfig()
        }

        val newProxyConfig = createProxyConfig(
            proxyConfig,
            "sip:$username@$domain",
            authInfo
        )
        core.addProxyConfig(newProxyConfig)
        core.defaultProxyConfig = newProxyConfig
        core.defaultAccount = account

//        core.addListener(coreListener)

        account.addListener { _, _, _ ->
        }
    }

    private fun createProxyConfig(
        proxyConfig: ProxyConfig,
        aor: String,
        authInfo: AuthInfo
    ): ProxyConfig {
        val address = core.createAddress(aor)
        proxyConfig.identityAddress = address

        proxyConfig.serverAddr = "<sip:${server}:5061;transport=tls>"
        proxyConfig.setRoute("<sip:${server}:5061;transport=tls>")

        proxyConfig.realm = authInfo.realm
        proxyConfig.enableRegister(true)
        proxyConfig.avpfMode = AVPFMode.Disabled
        proxyConfig.enablePublish(false)
        proxyConfig.dialEscapePlus = false
        return proxyConfig
    }

    private val audioDeviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>?) {
            if (!addedDevices.isNullOrEmpty()) {
                Log.d(debugTag,"[${addedDevices.size}] new device(s) have been added")
                core.reloadSoundDevices()
            }
        }

        override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>?) {
            if (!removedDevices.isNullOrEmpty()) {
                Log.d(debugTag,"[${removedDevices.size}] existing device(s) have been removed")
                core.reloadSoundDevices()
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

            if(
                device.type == AudioDevice.Type.Earpiece &&
                device.id.contains("openSLES")
            ) {
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

//   TODO: implement stop core method
//    fun stop() {
//        Log.d(debugTag,"Stopping...")
//        notificationsManager.destroy()
//        audioManager.unregisterAudioDeviceCallback(audioDeviceCallback)
//        core.stop()
//        coreStarted = false
//        _lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
//    }
}