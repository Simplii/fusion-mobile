package net.fusioncomm.android.services

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import net.fusioncomm.android.FMCore
import net.fusioncomm.android.notifications.NotificationsManager
import net.fusioncomm.android.telecom.CallsManager

class FusionCallService : Service() {
    private val debugTag = "MDBM CallService"

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(debugTag, "call service started")
        if (NotificationsManager.notification != null && intent != null) {
            val notificationId = intent.getIntExtra(NotificationsManager.INTENT_NOTIF_ID, 12)
            Log.d(debugTag,"notificationId = $notificationId")
            ServiceCompat.startForeground(
                this,
                notificationId,
                NotificationsManager.notification!!,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
                } else {
                    0
                },
            )
            NotificationsManager.onCallServiceStart(this)
        }
        return super.onStartCommand(intent, flags, startId)
    }


    override fun onDestroy() {
        Log.d(debugTag, "call service stopped ")
        NotificationsManager.onCallServiceDestroied()
        super.onDestroy()
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(debugTag, "call service created ")
    }

}