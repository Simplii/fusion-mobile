package net.fusioncomm.android.compatibility

import android.annotation.TargetApi
import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.telephony.PhoneNumberUtils
import android.text.Spannable
import android.text.SpannableString
import android.text.style.ForegroundColorSpan
import android.util.Log
import androidx.annotation.ColorRes
import androidx.core.app.NotificationCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import net.fusioncomm.android.FMCore
import net.fusioncomm.android.FMUtils
import net.fusioncomm.android.R
import net.fusioncomm.android.notifications.Contact
import net.fusioncomm.android.notifications.Notifiable
import net.fusioncomm.android.notifications.NotificationsManager
import org.linphone.core.Call
import java.io.IOException
import java.net.URL

@TargetApi(31)
class Api31Compatibility {

    companion object {
        private const val debugTag = "MDBM API31"
        private var pic: Bitmap? = null

        private suspend fun getImage(url:URL): Bitmap? = run {
            return withContext(Dispatchers.IO) {
                try {
                    BitmapFactory.decodeStream(url.openStream())
                } catch (e: IOException) {
                    Log.d(debugTag, "${e.message} url=$url")
                    null
                }
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
            val callerNumber :String = FMUtils.getPhoneNumber(call.remoteAddress)
            val callerId = FMUtils.getDisplayName(call.remoteAddress)
            val formattedCallerNumber = PhoneNumberUtils.formatNumber(callerNumber,"US")
            val contact:Contact? = NotificationsManager.contacts[callerNumber]

            val avatarLink: String = contact?.avatar ?: ""
            if(avatarLink.isNotEmpty()){
                runBlocking {
                    pic = getImage(URL(avatarLink))
                }
            }
            val displayName: String = contact?.name ?: callerId.ifEmpty { formattedCallerNumber }

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
                .setSmallIcon(R.drawable.ic_on_call)
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
            val callerNumber :String = FMUtils.getPhoneNumber(call.remoteAddress)
            val formattedCallerNumber = PhoneNumberUtils.formatNumber(callerNumber,"US")
            val contact:Contact? = NotificationsManager.contacts[callerNumber]
            val avatarLink: String = contact?.avatar ?: ""
            Log.d(debugTag, "avatar $avatarLink")
            if(avatarLink.isNotEmpty()){
                runBlocking {
                    pic = getImage(URL(avatarLink))
                }
            }
            val displayName: String = contact?.name ?: formattedCallerNumber
            val callPersonBuilder: Person.Builder = Person.Builder()
                .setName(displayName)
                .setImportant(true)
            pic?.let{
                callPersonBuilder.setIcon(IconCompat.createWithAdaptiveBitmap(it))
            }
            val incomingCaller = callPersonBuilder.build()
            val declineIntent = notificationsManager.getCallDeclinePendingIntent(notifiable)
            val unholdIntent = notificationsManager.getUnholdCallPendingIntent(notifiable)
            var unholdAction: NotificationCompat.Action? = null
            var notificationText = ""
            when (call.state) {
                Call.State.Pausing, Call.State.Paused -> {
                    notificationText = "Call on hold - $formattedCallerNumber"
                    unholdAction = NotificationCompat.Action.Builder(
                        IconCompat.createWithResource(context, R.drawable.ic_call_on_hold),
                       "Unhold",
                        unholdIntent
                    ).build()
                } else -> {
                    notificationText = "Call in progress - $formattedCallerNumber"
                }
            }
            val builder = NotificationCompat.Builder(context, context.getString(R.string.notification_channel_call_service_id))
                .setFullScreenIntent(pendingIntent, false)
                .setContentText(notificationText)
                .setContentIntent(pendingIntent)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
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

            if(unholdAction != null){
                builder.addAction(unholdAction)
                builder.setSmallIcon(R.drawable.ic_call_on_hold)
            } else {
                builder.setSmallIcon(R.drawable.ic_on_call)
            }
            pic = null
            return builder.build()
        }
    }

}