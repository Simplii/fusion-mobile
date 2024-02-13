package net.fusioncomm.android.compatibility

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import net.fusioncomm.android.notifications.Contact
import net.fusioncomm.android.notifications.Notifiable
import net.fusioncomm.android.notifications.NotificationsManager
import org.linphone.core.Call
import org.linphone.mediastream.Version

class Compatibility {
    companion object {
        private const val debugTag = "MDBM Compatibility"

        fun createNotificationChannels(
            context: Context,
            notificationManager: NotificationManagerCompat
        ) {
            Log.d(debugTag, "create notifications channels")
                // use service channel to create push active calls notifications
                Api26Compatibility.createCallServiceChannel(context, notificationManager)
                Api26Compatibility.createMissedCallChannel(context, notificationManager)
                Api26Compatibility.createIncomingCallChannel(context, notificationManager)

//  TODO: Add chat notification channels
//                if (Version.sdkAboveOrEqual(Version.API29_ANDROID_10)) {
//                    Api29Compatibility.createMessageChannel(context, notificationManager)
//                } else {
//                    Api26Compatibility.createMessageChannel(context, notificationManager)
//                }

        }

        fun createIncomingCallNotification(
            context: Context,
            call: Call,
            notifiable: Notifiable,
            pendingIntent: PendingIntent,
            notificationsManager: NotificationsManager,
            contact: Contact?
        ): Notification {
            if ( Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                return Api31Compatibility.createIncomingCallNotification(
                    context,
                    call,
                    notifiable,
                    pendingIntent,
                    notificationsManager,
                    contact
                )
            }
            return Api26Compatibility.createIncomingCallNotification(
                context,
                call,
                notifiable,
                pendingIntent,
                notificationsManager,
                contact
            )
        }

        fun createCallNotification (
            context: Context,
            call: Call,
            notifiable: Notifiable,
            pendingIntent: PendingIntent,
            notificationsManager: NotificationsManager,
            contact: Contact?
        ) : Notification {
            if ( Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                return Api31Compatibility.createCallNotification(
                    context,
                    call,
                    notifiable,
                    pendingIntent,
                    notificationsManager,
                    contact,
                )
            }
            return Api26Compatibility.createCallNotification(
                context,
                call,
                notifiable,
                pendingIntent,
                notificationsManager,
                contact
            )
        }

        fun setShowWhenLocked(activity: Activity, enable: Boolean) {
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.O_MR1) {
                Api23Compatibility.setShowWhenLocked(activity, enable)
            } else {
                Api27Compatibility.setShowWhenLocked(activity, enable)
            }
        }

        fun setTurnScreenOn(activity: Activity, enable: Boolean) {
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.O_MR1) {
                Api23Compatibility.setTurnScreenOn(activity, enable)
            } else {
                Api27Compatibility.setTurnScreenOn(activity, enable)
            }
        }

        fun requestDismissKeyguard(activity: Activity) {
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.O_MR1) {
                Api23Compatibility.requestDismissKeyguard(activity)
            } else {
                Api27Compatibility.requestDismissKeyguard(activity)
            }
        }


    }
}