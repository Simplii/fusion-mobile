package net.fusioncomm.android.services

import android.Manifest
import android.app.ForegroundServiceStartNotAllowedException
import android.app.Notification
import android.app.Service
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import net.fusioncomm.android.notifications.NotificationsManager
import net.fusioncomm.android.telecom.CallsManager

class FusionCallService : Service() {
    private val debugTag = "MDBM CallService"

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(debugTag, "call service started")
        val notificationId: Int = intent?.getIntExtra(NotificationsManager.INTENT_NOTIF_ID, 0) ?: 0
        val notification: Notification? = NotificationsManager.activeNotification[notificationId]
        val answerCall = intent?.getBooleanExtra("AnswerCall", false)

        if (notification != null) {
            Log.d(debugTag,"notificationId = $notificationId ")
            val recordPermission =
                ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)

            if (recordPermission == PackageManager.PERMISSION_DENIED) {
                Log.d(debugTag, "no audio record permission")
                stopSelf()
            }
            try {
                ServiceCompat.startForeground(
                    this,
                    notificationId,
                    notification,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
                    } else {
                        0
                    },
                )
                NotificationsManager.onCallServiceStart(this, startId,notificationId)
                //FIXME: this won't work when accepting multiple calls from notification
//                if (answerCall == true) {
//                    CallsManager.answerCall()
//                }
            } catch (e:  Exception) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                    && e is ForegroundServiceStartNotAllowedException
                ) {
                    // App not in a valid state to start foreground service
                    // (e.g. started from bg)
                    Log.d(debugTag, "${e.message} ${e.cause}")

                }
                Log.d(debugTag, "${e.message} ${e.cause}")
            }
        }
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onDestroy() {
        Log.d(debugTag, "call service stopped ")
        NotificationsManager.onCallServiceDestroyed()
        super.onDestroy()
    }

    override fun onCreate() {
        super.onCreate()
//        Log.d(debugTag, "call service created ")
    }

}