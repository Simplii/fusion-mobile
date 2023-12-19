package net.fusioncomm.android

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.PackageManager.FEATURE_TELEPHONY_SUBSCRIPTION
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Bundle
import android.util.JsonWriter
import android.util.Log
import com.tekartik.sqflite.SqflitePlugin;

import com.google.gson.Gson
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import io.flutter.util.ViewUtils.getActivity
import org.linphone.core.*
import org.linphone.core.CoreListenerStub
import java.math.BigInteger
import java.security.MessageDigest
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.telephony.SubscriptionManager
import android.telephony.SubscriptionManager.DEFAULT_SUBSCRIPTION_ID
import android.view.KeyEvent
import androidx.core.content.getSystemService

class MainActivity : FlutterFragmentActivity() {
    private lateinit var core: Core
    // private lateinit var channel: MethodChannel
    // switched it to companion obj to be able to invoke flutter methods from
    // native boradcastRecivers and services
    companion object {
        lateinit var channel: MethodChannel
    }
    private var username: String = ""
    private var password: String = ""
    private var domain: String = ""
    private var server: String = "services.fusioncom.co"
    private var uuidCalls: MutableMap<String, Call> = mutableMapOf();
//    lateinit var volumeReceiver : VolumeReceiver
    val versionName = BuildConfig.VERSION_NAME
    private var appOpenedFromBackground : Boolean = false

    lateinit var audioManager:AudioManager
    lateinit var telephonyManager: TelephonyManager;
    var myPhoneNumber:String = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState);
        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        setupCore();
//        setupBroadcastReciver()
        val incomingCallId : String? = getIntent().getStringExtra("payload")
        if(incomingCallId != null){
            appOpenedFromBackground = true
            getIntent().removeExtra("payload");
        }
    }

    override fun onStart() {
        super.onStart()
        phoneStateListener()
    }

    override fun onPause() {
        super.onPause()
        phoneStateListener()
    }

    override fun onResume() {
        super.onResume()
        val incomingCallId: String? = intent.getStringExtra("payload")
        if(incomingCallId != null && incomingCallId.isNotEmpty()){
            appOpenedFromBackground = true
            getIntent().removeExtra("payload");
        }
    }

    // override fun onDestroy() {
    //     super.onDestroy()
    //     // terminating call here not reliable, this function sometimes won't fire if
    //     // app is closed from recent apps list or killed by android system.
    //     // core?.currentCall?.terminate()
    //    unregisterReceiver(volumeReceiver)
    // }

//    private fun setupBroadcastReciver(){
//        volumeReceiver = VolumeReceiver()
//        val filter = IntentFilter()
//        filter.addAction("android.media.VOLUME_CHANGED_ACTION")
//        registerReceiver(volumeReceiver, filter)
//    }

   override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
       if ((keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)){
           core.stopRinging()
       }
       return super.onKeyDown(keyCode, event);
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
            var newDevice: Array<String> = arrayOf(audioDevice.id, audioDevice.type.name);

           if(!newDevice.isNullOrEmpty()){

                var gson = Gson();

                channel.invokeMethod(
                        "lnAudioDeviceChanged",
                       mapOf(Pair("audioDevice", gson.toJson(newDevice)),
                            Pair("activeCallOutput", core.currentCall?.outputAudioDevice?.id),
                            Pair("defaultMic", core.defaultOutputAudioDevice.id))
                    );
           }
            
        }
    
        override fun onAudioDevicesListUpdated(@NonNull core: Core) {
            // This callback will be triggered when the available devices list has changed,
            // for example after a bluetooth headset has been connected/disconnected.
            var devicesList: Array<Array<String>> = arrayOf()
            for (device in core.extendedAudioDevices) {
                devicesList = devicesList.plus(
                    arrayOf(device.deviceName, device.id, device.type.name)
                )
            }

            var gson = Gson();

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
            val uuid = findUuidByCall(call)
            print("call state changed")
            print(uuid)
            print(state)
            print(call)
            when (state) {
                Call.State.Idle -> {
                    channel.invokeMethod(
                        "lnIdle",
                        mapOf(Pair("uuid", uuid))
                    )
                }
                Call.State.IncomingReceived -> {
                    audioManager.mode = AudioManager.MODE_NORMAL;
                    audioManager.isSpeakerphoneOn = true;
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
                }
                Call.State.PushIncomingReceived -> {
                    audioManager.mode = AudioManager.MODE_NORMAL;
                    audioManager.isSpeakerphoneOn = true;
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
                    audioManager.isSpeakerphoneOn = false;
                    uuidCalls[uuid] = call
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
                    audioManager.mode = AudioManager.MODE_NORMAL;
                    audioManager.isSpeakerphoneOn = false;
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

    private fun setupCore() {
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val factory = Factory.instance()
        factory.setDebugMode(true, "Hello fusion")
        core = factory.createCore(null, null, this)
        core.enableIpv6(false)
        core.stunServer = "turn:$server"
        core.natPolicy?.stunServerUsername = "fuser"
        core.addAuthInfo(
            factory.createAuthInfo(
                "fuser", "fuser", "fpassword", null, null, null
            )
        )
        core.natPolicy?.enableTurn(true)
        core.enableEchoLimiter(true)
        core.enableEchoCancellation(true)

        if (core.hasBuiltinEchoCanceller()) {
            print("Device has built in echo canceler, disabling software echo canceler");
            core.enableEchoCancellation(false);
        }
        else {
            print("Device has no echo canceler, enabling software echo canceler");
            core.enableEchoCancellation(true);
        }

        core.natPolicy?.stunServer = server
        core.remoteRingbackTone = "android.resource://net.fusioncomm.android/" + R.raw.outgoing
        core.ring = RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_RINGTONE).toString();
        core.config.setBool("audio", "android_pause_calls_when_audio_focus_lost", false)
    }

    private fun register() {
        val transportType = TransportType.Tcp
        val authInfo =
            Factory.instance().createAuthInfo(username, null, password, null, null, domain, null)
        val accountParams = core.createAccountParams()
        val identity = Factory.instance().createAddress("sip:$username@$domain")
        accountParams.identityAddress = identity

        val address = Factory.instance().createAddress("sip:${server}:5060")
        address?.transport = transportType
        accountParams.serverAddress = address
        accountParams.registerEnabled = true
        accountParams.setRoutesAddresses(arrayOf(address))
        accountParams.avpfMode = AVPFMode.Disabled
        accountParams.dialEscapePlusEnabled = false
        accountParams.publishEnabled = false
        accountParams.identityAddress = core.createAddress("sip:" + username + "@" + domain)

        print("register")
        print(address)

        val account = core.createAccount(accountParams)

        core.addAuthInfo(authInfo)
        core.addAccount(account)
        core.loadConfigFromXml("android.resource://net.fusioncomm.net/" + R.raw.fusion_config)

        var proxyConfig = core.defaultProxyConfig
        if (proxyConfig == null) {
            proxyConfig = core.createProxyConfig()
        }

        var newProxyConfig = createProxyConfig(
            proxyConfig,
            "sip:" + username + "@" + domain,
            authInfo
        )
        print("proxyconfig")
        print(newProxyConfig)
        core.addProxyConfig(newProxyConfig)
        core.defaultProxyConfig = newProxyConfig
        core.defaultAccount = account
        core.addListener(coreListener)
        account.addListener { _, state, message ->
        }
        core.start()
        sendDevices()
        getAppVersion()
        getMyPhoneNumber()
    }

    private fun handleCallStateChange(state: Int){
        when (state){
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                channel.invokeMethod("setPhoneState",
                    mapOf(Pair("onCellPhoneCall", true)))
                val calls : Array<Call>? = core?.calls
                if (calls != null) {
                    for(call in calls){
                        call.pause()
                    }
                }
                Log.d("phoneStateListener",
                    "Busy: At least one call exists that is dialing, active, or on hold, " +
                            "and no calls are ringing or waiting")
            }
            TelephonyManager.CALL_STATE_IDLE ->{
                channel.invokeMethod("setPhoneState",
                    mapOf(Pair("onCellPhoneCall", false)))
                Log.d("phoneStateListener",
                    "Not Available:: Neither Ringing nor in a Call")
            }
            else -> Log.d("phoneStateListener", "callState ${state}")
        }
    }

    private fun phoneStateListener() {
        Log.d("phoneStateListener","starting phone state listener")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            Log.d("phoneStateListener","android >= 12")
            val permission = ContextCompat.checkSelfPermission(this,
                    Manifest.permission.READ_PHONE_STATE)

            if (permission == PackageManager.PERMISSION_GRANTED){
                telephonyManager =
                        getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        packageManager.hasSystemFeature(FEATURE_TELEPHONY_SUBSCRIPTION)){
                    val subscriptionManager: SubscriptionManager =
                            getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                    Log.d("MBDM", "${subscriptionManager.getPhoneNumber(DEFAULT_SUBSCRIPTION_ID)}")
                    myPhoneNumber = subscriptionManager.getPhoneNumber(DEFAULT_SUBSCRIPTION_ID)
                } else {
                    myPhoneNumber = telephonyManager.line1Number ?: "";
                }

                telephonyManager.registerTelephonyCallback(
                        mainExecutor,
                        object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                            override fun onCallStateChanged(state: Int) {
                                handleCallStateChange(state)
                            }
                        })
            }

        } else {
            Log.d("phoneStateListener","android < 12")
            telephonyManager =
                    getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            val callStateListener: PhoneStateListener = object : PhoneStateListener() {
                override fun onCallStateChanged(state: Int, incomingNumber: String?) {
                    handleCallStateChange(state)
                }
            }
            // stopping old listener
            telephonyManager.listen(callStateListener, PhoneStateListener.LISTEN_NONE)
            // starting new listener
            telephonyManager.listen(callStateListener, PhoneStateListener.LISTEN_CALL_STATE)
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

        var gson = Gson();
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
        var appversion: Array<String> = arrayOf()
        appversion = appversion.plus(versionName)
        var gson = Gson();
        channel.invokeMethod("setAppVersion",  gson.toJson(versionName) )
    }

    private fun getMyPhoneNumber(){
        var gson = Gson();
        channel.invokeMethod("setMyPhoneNumber",  gson.toJson(myPhoneNumber) )
    }

    private fun createProxyConfig(
        proxyConfig: ProxyConfig,
        aor: String,
        authInfo: AuthInfo
    ): ProxyConfig {
        var address = core.createAddress(aor)
        proxyConfig.identityAddress = address

        proxyConfig.serverAddr = "<sip:${server}:5060;transport=tcp>"
        proxyConfig.setRoute("<sip:${server}:5060;transport=tcp>")

        proxyConfig.realm = authInfo.realm
        proxyConfig.enableRegister(true)
        proxyConfig.avpfMode = AVPFMode.Disabled
        proxyConfig.enablePublish(false)
        proxyConfig.dialEscapePlus = false
        return proxyConfig
    }


    private fun unregister() {
        val account = core.defaultAccount
        account ?: return
        val params = account.params
        val clonedParams = params.clone()

        clonedParams.registerEnabled = false

        account.params = clonedParams
        finishAndRemoveTask();
    }

    private fun findUuidByCall(call: Call): String {
        if (call.callLog.callId == null) {
            return ""
        } else {
            val callId = call.callLog.callId
            val md = MessageDigest.getInstance("MD5")
            val md5 = BigInteger(1, md.digest(callId.toByteArray()))
                .toString(16)
                .padStart(32, '0')
            var numbers: Array<String> = arrayOf<String>()

            for (i in 0..15) {
                numbers = numbers.plusElement(md5[i].toInt().toString(16))
            }

            var r = ""
            r = numbers[0] + numbers[1] + numbers[2] + numbers[3] + "-"
            r += numbers[4] + numbers[5] + "-"
            r += numbers[6] + numbers[7] + "-"
            r += numbers[8] + numbers[9] + "-"
            r += numbers[10] + numbers[11] + numbers[12] + numbers[13] + numbers[14] + numbers[15]

            uuidCalls.put(r, call)
            return r
        }
    }


    private fun outgoingCall(destination: String) {
        val remoteSipUri = destination
        val remoteAddress = core.interpretUrl(remoteSipUri)
        val params = core.createCallParams(null)
        if (remoteAddress != null && params != null) {
            params.mediaEncryption = MediaEncryption.None
            params.enableVideo(false)
            core.inviteAddressWithParams(remoteAddress, params)
        }
    }


    private fun findCallByUuid(uuid: String): Call? {
        return uuidCalls.get(uuid)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "net.fusioncomm.android/calling"
        );

        // Contacts Provider Channel
        ContactsProvider(MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "net.fusioncomm.ios/contacts"
        ), this)

        channel.setMethodCallHandler { call, result ->
            print("gotflmethod")
            print(call.method);
            print(call.arguments)
            if (call.method == "setSpeaker") {
                Log.d("TAG", "setspeaker");

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    var devices = audioManager.availableCommunicationDevices
                    Log.d("TAG", "searchspeakerddeivce");
                    for (device in devices) {
                        if (device.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                            Log.d("TAG", "setspeakernew");
                            audioManager.setCommunicationDevice(device);
                        }
                    }
                } else {
                    Log.d("TAG", "setspeakerold");
                    audioManager.isSpeakerphoneOn = true
                }
            } else if (call.method == "setEarpiece") {
                audioManager.isSpeakerphoneOn = false
            } else if (call.method == "lpAnswer") {
                var args = call.arguments as List<Any>
                var lpCall = findCallByUuid(args[0] as String)
                print("answering...")
                if (lpCall != null) {
                    lpCall.accept()
                }
            } else if (call.method == "lpSendDtmf") {
                var args = call.arguments as List<Any>
                var lpCall = findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    lpCall.sendDtmfs(args[1] as String)
                }
            } else if (call.method == "lpSetHold") {
                var args = call.arguments as List<Any>
                var lpCall = findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    if (args[1] as Boolean == false) {
                        lpCall.resume()
                    } else {
                        lpCall.pause()
                    }
                }
            } else if (call.method == "lpSetEchoCancellationEnabled") {
                var args = call.arguments as List<Any>
                core.enableEchoCancellation(args[0] as Boolean)
                sendDevices()
            } else if (call.method == "lpCalibrateEcho") {
                core.startEchoCancellerCalibration()
            } else if (call.method == "lpTestEcho") {
                core.startEchoTester(10)
            } else if (call.method == "lpStopTestEcho") {
                core.stopEchoTester()
                sendDevices()
            } else if (call.method == "lpSetEchoLimiterEnabled") {
                var args = call.arguments as List<Any>
                core.enableEchoLimiter(args[0] as Boolean)
                sendDevices()
            } else if (call.method == "lpSetDefaultInput") {
                var args = call.arguments as List<Any>
                Log.d("setinput", "gonna set default input")
                for (audioDevice in core.extendedAudioDevices) {
                    Log.d("setinput", "checking audio device" + audioDevice.id)
                    Log.d("setinput", "checking against" + args[0])
                    if (audioDevice.id == args[0]) {
                        Log.d("setinput", "found the default input")
                        core.defaultInputAudioDevice = audioDevice;
                        for  (call in core.calls) {
                            Log.d("setinput", "setting the default input for a call")
                            call.inputAudioDevice = audioDevice
                            Log.d("setinput", audioDevice.id)
                        }
                    }
                }
//                 sendDevices()
            } else if (call.method == "lpSetDefaultOutput") {
                var args = call.arguments as List<Any>
                for (audioDevice in core.extendedAudioDevices) {
                    Log.d("setou8tput", "out checking audio device" + audioDevice.id)
                    Log.d("output", "out checking against" + args[0])

                    if (audioDevice.id == args[0]) {
                        core.defaultOutputAudioDevice = audioDevice;
                        for  (call in core.calls) {
                    Log.d("setinput", "setting the default input for a call")

                            call.outputAudioDevice = audioDevice
                        }
                    }
                }
//                 sendDevices()
            } else if(call.method == "lpSetActiveCallOutput") {
                var args = call.arguments as List<Any>

                for (audioDevice in core.audioDevices) {
                    if (audioDevice.id == args[0]) {
                        Log.d("lpSetActiveCallOutput", "args" +args[0])
                        Log.d("lpSetActiveCallOutput", "audio device" +audioDevice.id)

                        core.currentCall?.outputAudioDevice = audioDevice
                    }
                }
            }
            else if (call.method == "lpSetSpeaker") {
                var args = call.arguments as List<Any>
                var enableSpeaker = args[0] as Boolean
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
//                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION this line causing older
//                android version to get audio stuck in ear

                Log.d("lpSetActiveCallOutput" , "set speaker")
                for (audioDevice in core.extendedAudioDevices) {
                    if (!enableSpeaker && audioDevice.type == AudioDevice.Type.Earpiece
                            && audioDevice.id.contains("openSLES")) {
                        for  (call in core.calls) {
                            call.outputAudioDevice = audioDevice
                        }
                        audioManager.isSpeakerphoneOn = false
                    } else if (enableSpeaker && audioDevice.type == AudioDevice.Type.Speaker) {
                        for  (call in core.calls) {
                            call.outputAudioDevice = audioDevice
                        }
                        audioManager.isSpeakerphoneOn = true
                    }
                }
//                sendDevices()
            } else if (call.method == "lpSetBluetooth"){
                for (audioDevice in core.audioDevices) {
                    if (audioDevice.type == AudioDevice.Type.Bluetooth) {
                        for  (call in core.calls) {
                            call.outputAudioDevice = audioDevice
                        }
                    }
                }
//                sendDevices()
            } else if (call.method == "lpMuteCall") {
                var args = call.arguments as List<Any>
                var lpCall = findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    lpCall.microphoneMuted = true
                }
            } else if (call.method == "lpUnmuteCall") {
                var args = call.arguments as List<Any>
                var lpCall = findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    lpCall.microphoneMuted = false
                }
            } else if (call.method == "lpRefer") {
                var args = call.arguments as List<Any>
                var lpCall = findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    lpCall.transfer(args[1] as String)
                }
            } else if (call.method == "lpStartCall") {
                var args = call.arguments as List<Any>
                outgoingCall(args[0] as String)
            } else if (call.method == "lpEndCall") {
                var args = call.arguments as List<Any>
                var lpCall = findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    lpCall.terminate()
                }
            } else if (call.method == "lpAssistedTransfer") {
                var args = call.arguments as List<Any>
                var lpCallToTransfer = findCallByUuid(args[0] as String)
                var activeCall = findCallByUuid(args[1] as String)

                if(lpCallToTransfer != null && activeCall != null){
                    lpCallToTransfer.transferToAnother(activeCall)
                }

            } else if (call.method == "lpRegister") {
                var args = call.arguments as List<Any>
                username = args[0] as String
                password = args[1] as String
                domain = args[2] as String
                register()
            } else if (call.method == "lpUnregister") {
                unregister()
            }
        }
    }
}