package net.fusioncomm.android

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import org.linphone.core.AVPFMode
import org.linphone.core.AudioDevice
import org.linphone.core.AuthInfo
import org.linphone.core.Call
import org.linphone.core.Core
import org.linphone.core.Factory
import org.linphone.core.MediaEncryption
import org.linphone.core.ProxyConfig
import org.linphone.core.TransportType
import java.math.BigInteger
import java.security.MessageDigest

class FMCore(private val context: Context, private val channel:MethodChannel) {

    private val DebugTag = "MDBM FMCORE"
    private val factory: Factory = Factory.instance()
    private val server: String = "services.fusioncom.co"
    private val audioManager:AudioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    companion object{
        lateinit var core:Core
        var coreStarted = false
        var uuidCalls: MutableMap<String, Call> = mutableMapOf()

        private fun findCallByUuid(uuid: String): Call? {
            return uuidCalls[uuid]
        }


        fun findUuidByCall(call: Call?): String {
            if (call == null) return ""

            val callId = call.callLog.callId
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

            uuidCalls[r] = call
            return r
        }
    }


    init {
        setupCore()
        setFlutterActionsHandler()
        val started: Int = core.start()
        coreStarted = started == 0
    }

    private fun setupCore() {
        Log.d("MDBM", "setup core")
        core = factory.createCore(null, null, context)
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
    }

    private fun outgoingCall(destination: String) {
        val remoteAddress = core.interpretUrl(destination)
        val params = core.createCallParams(null)
        if (remoteAddress != null && params != null) {
            params.mediaEncryption = MediaEncryption.None
            params.enableVideo(false)
            core.inviteAddressWithParams(remoteAddress, params)
        }
    }

    private fun unregister() {
        val account = core.defaultAccount
        account ?: return
        val params = account.params
        val clonedParams = params.clone()

        clonedParams.registerEnabled = false

        account.params = clonedParams
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
                val lpCall = findCallByUuid(args[0] as String)
                Log.d("MDBM", "LpAnswer")
                lpCall?.accept()
            } else if (call.method == "lpSendDtmf") {
                val args = call.arguments as List<*>
                val lpCall = findCallByUuid(args[0] as String)
                lpCall?.sendDtmfs(args[1] as String)
            } else if (call.method == "lpSetHold") {
                val args = call.arguments as List<*>
                val lpCall = findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    if (!(args[1] as Boolean)) {
                        lpCall.resume()
                    } else {
                        lpCall.pause()
                    }
                }
            } else if (call.method == "lpSetEchoCancellationEnabled") {
                val args = call.arguments as List<*>
                core.enableEchoCancellation(args[0] as Boolean)
//                sendDevices()
            } else if (call.method == "lpCalibrateEcho") {
                core.startEchoCancellerCalibration()
            } else if (call.method == "lpTestEcho") {
                core.startEchoTester(10)
            } else if (call.method == "lpStopTestEcho") {
                core.stopEchoTester()
//                sendDevices()
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
                val args = call.arguments as List<*>

                for (audioDevice in core.audioDevices) {
                    if (audioDevice.id == args[0]) {
                        Log.d("lpSetActiveCallOutput", "args" +args[0])
                        Log.d("lpSetActiveCallOutput", "audio device" +audioDevice.id)

                        core.currentCall?.outputAudioDevice = audioDevice
                    }
                }
            }
            else if (call.method == "lpSetSpeaker") {
                val args = call.arguments as List<*>
                val enableSpeaker = args[0] as Boolean
//                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION this line causing older
//                android version to get audio stuck in ear
                Log.d("lpSetActiveCallOutput" , "set speaker")
                for (audioDevice in core.extendedAudioDevices) {
                    if (!enableSpeaker && audioDevice.type == AudioDevice.Type.Earpiece
                        && audioDevice.id.contains("openSLES")) {
                        for  (coreCall in core.calls) {
                            coreCall.outputAudioDevice = audioDevice
                        }
                        audioManager.isSpeakerphoneOn = false
                    } else if (enableSpeaker && audioDevice.type == AudioDevice.Type.Speaker) {
                        for  (coreCall in core.calls) {
                            coreCall.outputAudioDevice = audioDevice
                        }
                        audioManager.isSpeakerphoneOn = true
                    }
                }
//                sendDevices()
            } else if (call.method == "lpSetBluetooth"){
                for (audioDevice in core.audioDevices) {
                    if (audioDevice.type == AudioDevice.Type.Bluetooth) {
                        for  (coreCall in core.calls) {
                            coreCall.outputAudioDevice = audioDevice
                        }
                    }
                }
//                sendDevices()
            } else if (call.method == "lpMuteCall") {
                val args = call.arguments as List<*>
                val lpCall = findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    lpCall.microphoneMuted = true
                }
            } else if (call.method == "lpUnmuteCall") {
                val args = call.arguments as List<*>
                val lpCall = findCallByUuid(args[0] as String)
                if (lpCall != null) {
                    lpCall.microphoneMuted = false
                }
            } else if (call.method == "lpRefer") {
                val args = call.arguments as List<*>
                val lpCall = findCallByUuid(args[0] as String)
                lpCall?.transfer(args[1] as String)
            } else if (call.method == "lpStartCall") {
                val args = call.arguments as List<*>
                outgoingCall(args[0] as String)
            } else if (call.method == "lpEndCall") {
                val args = call.arguments as List<*>
                val lpCall = findCallByUuid(args[0] as String)
                lpCall?.terminate()
            } else if (call.method == "lpAssistedTransfer") {
                val args = call.arguments as List<*>
                val lpCallToTransfer = findCallByUuid(args[0] as String)
                val activeCall = findCallByUuid(args[1] as String)

                if(lpCallToTransfer != null && activeCall != null){
                    lpCallToTransfer.transferToAnother(activeCall)
                }

            } else if (call.method == "lpRegister") {
                val args = call.arguments as List<*>
                val username = args[0] as String
                val password = args[1] as String
                val domain = args[2] as String
                register(username,password,domain)
            } else if (call.method == "lpUnregister") {
                unregister()
            } else {
                Log.d(DebugTag,"setFlutterActionHandler call = $call")
                results.notImplemented()
            }
        }
    }

    private fun register(
        username:String,
        password:String,
        domain:String,
    ) {
        Log.d("MDBM", "LPRegister FMCOre $username $password $domain ")
        val transportType = TransportType.Tcp
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

        val address = Factory.instance().createAddress("sip:${server}:5060")
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

        proxyConfig.serverAddr = "<sip:${server}:5060;transport=tcp>"
        proxyConfig.setRoute("<sip:${server}:5060;transport=tcp>")

        proxyConfig.realm = authInfo.realm
        proxyConfig.enableRegister(true)
        proxyConfig.avpfMode = AVPFMode.Disabled
        proxyConfig.enablePublish(false)
        proxyConfig.dialEscapePlus = false
        return proxyConfig
    }


}