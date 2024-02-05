package net.fusioncomm.android

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import org.linphone.core.Call
import org.linphone.core.tools.service.CoreManager


class FusionService: Service() {

    companion object {
       var serviceStarted: Boolean = false
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        serviceStarted = true
        super.onCreate()
    }
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if(CoreManager.isReady()){
            val calls : Array<Call> = CoreManager.instance().core.calls
            if(calls.isNotEmpty()){
                for(call in calls){
                    call.terminate()
                }
            }
        }
        //stop service
        this.stopSelf()
        serviceStarted = false
    }

    override fun onDestroy() {
        serviceStarted = false
        super.onDestroy()
        Log.d("fusionService","destroyed")
    }
}