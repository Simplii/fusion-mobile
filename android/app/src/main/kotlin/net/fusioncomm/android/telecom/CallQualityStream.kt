package net.fusioncomm.android.telecom

import android.util.Log
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.Job
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import net.fusioncomm.android.FMCore
import org.linphone.core.Call

/*  
    Created by Zaid Jamil.
*/

class CallQualityStream: EventChannel.StreamHandler {
    private val scope = MainScope()
    private var job: Job? = null

    override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
        var call: Call = FMCore.core.currentCall ?: return
        job = scope.launch {
            var callActive = true
            while(callActive) {
                delay(5000)
                eventSink.success(call.currentQuality)
                if( call.state == Call.State.Released ||
                    call.state == Call.State.End ||
                    call.state == Call.State.Error ||
                    call.state == Call.State.Paused
                ) {
                    val newCall: Call? = FMCore.core.currentCall
                    if(newCall != null) {
                        call = newCall
                    } else {
                        job?.cancel()
                        callActive = false
                    }
                }
            }
        }

    }
    override fun onCancel(arguments: Any?) {
        job?.cancel()
    }

}