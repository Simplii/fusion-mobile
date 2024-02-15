package net.fusioncomm.android.compatibility

import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.graphics.drawable.IconCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import net.fusioncomm.android.R
import net.fusioncomm.android.notifications.Contact
import net.fusioncomm.android.notifications.Notifiable
import net.fusioncomm.android.notifications.NotificationsManager
import org.linphone.core.Call
import java.net.URL

class Api31Compatibility {

    companion object {
        private const val debugTag = "MDBM API31"
        private var pic: Bitmap? = null

        private suspend fun getImage(url:URL): Bitmap? = run {
            return withContext(Dispatchers.IO) {
                BitmapFactory.decodeStream(url.openStream())
            }
        }

        fun createIncomingCallNotification (
            context: Context,
            call: Call,
            notifiable: Notifiable,
            pendingIntent: PendingIntent,
            notificationsManager: NotificationsManager,
        ) : Notification {
            Log.d(debugTag, "creating incoming call notification ...")
            val cleanSip:String = call.remoteAddress.asStringUriOnly().replace("sip:", "")
            val callerNumber: String = cleanSip.substring(0,cleanSip.indexOf("@"))
            val contact:Contact? = NotificationsManager.contacts[callerNumber]

            val avatarLink: String = contact?.avatar ?: ""
            if(avatarLink.isNotEmpty()){
                runBlocking {
                    pic = getImage(URL(avatarLink))
                }
            }
            val displayName: String = contact?.name ?: callerNumber

            val incomingCallerBuilder: Person.Builder = Person.Builder()
                .setName(displayName)
                .setImportant(false)

            pic?.let{
                incomingCallerBuilder.setIcon(IconCompat.createWithAdaptiveBitmap(it))
            }
            val incomingCaller = incomingCallerBuilder.build()
            val declineIntent = notificationsManager.getCallDeclinePendingIntent(notifiable)
            val answerIntent = notificationsManager.getCallAnswerPendingIntent(notifiable)

            val builder = NotificationCompat.Builder(context, context.getString(R.string.notification_channel_incoming_call_id))
                .setContentIntent(pendingIntent)
                .setSmallIcon(R.drawable.phone_filled_white)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setWhen(System.currentTimeMillis())
                .setAutoCancel(false)
                .setShowWhen(true)
                .setOngoing(true)
                .setStyle(
                    NotificationCompat.CallStyle.forIncomingCall(
                        incomingCaller,
                        declineIntent,
                        answerIntent
                    ).setIsVideo(false)
                )
                .addPerson(incomingCaller)
                .setFullScreenIntent(pendingIntent, true )
                .setPriority(NotificationCompat.PRIORITY_HIGH)
            if(pic != null){
                builder.setSmallIcon(IconCompat.createWithAdaptiveBitmap(pic!!))
            }
            pic = null
            return builder.build()
        }

        fun createCallNotification(
            context: Context,
            call: Call,
            notifiable: Notifiable,
            pendingIntent: PendingIntent,
            notificationsManager: NotificationsManager,
        ) :Notification {
            val cleanSip :String = call.remoteAddress.asStringUriOnly().replace("sip:", "")
            val callerNumber = cleanSip.substring(0,cleanSip.indexOf("@"))
            val contact:Contact? = NotificationsManager.contacts[callerNumber]
            val avatarLink: String = contact?.avatar ?: ""
            if(avatarLink.isNotEmpty()){
                runBlocking {
                    pic = getImage(URL(avatarLink))
                }
            }
            val displayName: String = contact?.name ?: callerNumber
            val callPersonBuilder: Person.Builder = Person.Builder()
                .setName(displayName)
                .setImportant(true)
            pic?.let{
                callPersonBuilder.setIcon(IconCompat.createWithAdaptiveBitmap(it))
            }
            val incomingCaller = callPersonBuilder.build()
            val declineIntent = notificationsManager.getCallDeclinePendingIntent(notifiable)
            val notificationText:String = when (call.state) {
                Call.State.Pausing, Call.State.Paused ->{
                    "Call on hold"
                }
                else -> {
                    "Call in progress"
                }
            }
            val builder = NotificationCompat.Builder(context, context.getString(R.string.notification_channel_call_service_id))
                .setFullScreenIntent(pendingIntent, false)
                .setContentText(notificationText)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setSmallIcon(R.drawable.phone_filled_white)
                .setAutoCancel(false)
                .setWhen(System.currentTimeMillis())
                .setShowWhen(true)
                .setOngoing(true)
                .setStyle(
                    NotificationCompat.CallStyle.forOngoingCall(
                        incomingCaller,
                        declineIntent
                    )
                )
                .addPerson(incomingCaller)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            pic = null
            return builder.build()
        }
    }

}