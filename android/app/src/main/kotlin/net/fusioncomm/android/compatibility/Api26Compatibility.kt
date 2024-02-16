package net.fusioncomm.android.compatibility

import android.annotation.TargetApi
import android.app.*
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.telephony.PhoneNumberUtils
import android.util.Log
import android.view.WindowManager
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import androidx.core.graphics.drawable.IconCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import net.fusioncomm.android.FMUtils
import net.fusioncomm.android.R
import net.fusioncomm.android.notifications.Contact
import net.fusioncomm.android.notifications.Notifiable
import net.fusioncomm.android.notifications.NotificationsManager
import org.linphone.core.Call
import java.net.URL

@TargetApi(26)
class Api26Compatibility {
    companion object {
        private const val debugTag = "MDBM API26"
        private var pic: Bitmap? = null

        private suspend fun getImage(url:URL): Bitmap? = run {
            return withContext(Dispatchers.IO) {
                BitmapFactory.decodeStream(url.openStream())
            }
        }

        fun createCallServiceChannel(context: Context, notificationManager: NotificationManagerCompat) {
            // Create service notification channel
            val id = context.getString(R.string.notification_channel_call_service_id)
            val name = context.getString(R.string.notification_channel_call_service_name)
            val description = context.getString(R.string.notification_channel_call_service_name)
            val channel = NotificationChannel(id, name, NotificationManager.IMPORTANCE_LOW)
            channel.description = description
            channel.enableVibration(false)
            channel.enableLights(false)
            channel.setShowBadge(false)
            notificationManager.createNotificationChannel(channel)
        }

        fun createMissedCallChannel(
            context: Context,
            notificationManager: NotificationManagerCompat
        ) {
            val id = context.getString(R.string.notification_channel_missed_call_id)
            val name = context.getString(R.string.notification_channel_missed_call_name)
            val description = context.getString(R.string.notification_channel_missed_call_name)
            val channel = NotificationChannel(id, name, NotificationManager.IMPORTANCE_LOW)
            channel.description = description
            channel.lightColor = context.getColor(R.color.notification_led_color)
            channel.enableVibration(true)
            channel.enableLights(true)
            channel.setShowBadge(true)
            notificationManager.createNotificationChannel(channel)
        }

        fun createIncomingCallChannel(
            context: Context,
            notificationManager: NotificationManagerCompat
        ) {
            // Create incoming calls notification channel
            val id = context.getString(R.string.notification_channel_incoming_call_id)
            val name = context.getString(R.string.notification_channel_incoming_call_name)
            val description = context.getString(R.string.notification_channel_incoming_call_name)
//            val audio :AudioAttributes = AudioAttributes.Builder()
//                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
//                .setLegacyStreamType(AudioManager.STREAM_RING)
//                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
//                .build()
            val channel = NotificationChannel(id, name, NotificationManager.IMPORTANCE_HIGH)
            channel.description = description
            channel.lightColor = context.getColor(R.color.notification_led_color)
            channel.enableVibration(true)
            channel.enableLights(true)
            channel.setShowBadge(true)
//            channel.setSound(
//                RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE),
//                audio
//            )
            notificationManager.createNotificationChannel(channel)
            Log.d(debugTag, "incoming channel created")
        }

        fun createIncomingCallNotification (
            context: Context,
            call: Call,
            notifiable: Notifiable,
            pendingIntent: PendingIntent,
            notificationsManager: NotificationsManager,
        ) : Notification {
            val notificationLayoutHeadsUp = RemoteViews(
                context.packageName,
                R.layout.incoming_call_notification
            )
            val callerNumber = FMUtils.getPhoneNumber(call.remoteAddress)
            val formattedCallerNumber = PhoneNumberUtils.formatNumber(callerNumber,"US")
            val contact:Contact? = NotificationsManager.contacts[callerNumber]
            Log.d(debugTag,"$contact")
            val displayName: String = contact?.name ?: formattedCallerNumber
            val number = contact?.number
            val callerAvatar = contact?.avatar ?: ""
            val notificationTitle = "Incoming call"
            notificationLayoutHeadsUp.setTextViewText(R.id.caller, displayName)
            notificationLayoutHeadsUp.setTextViewText(R.id.sip_uri, number)
            notificationLayoutHeadsUp.setTextViewText(R.id.incoming_call_info, notificationTitle)
            if(callerAvatar.isNotEmpty()){
                runBlocking {
                    pic = getImage(URL(callerAvatar))
                }
            }
            val contactAvatar: IconCompat = IconCompat.createWithResource(
                context,
                R.drawable.blank_avatar
            )
            var defaultUserPic: Bitmap = BitmapFactory.decodeResource(context.resources, R.drawable.blank_avatar)

            pic?.let {
                defaultUserPic = it
            }

            notificationLayoutHeadsUp.setImageViewBitmap(R.id.caller_picture, defaultUserPic)
            val p = Person.Builder()
                .setName(displayName)
                .setIcon(contactAvatar)
                .setKey(displayName)
                .build()

            val notificationBuilder =  NotificationCompat.Builder(
                    context,
                    context.getString(R.string.notification_channel_incoming_call_id)
                )
                .setStyle(NotificationCompat.DecoratedCustomViewStyle())
                .addPerson(p)
                .setSmallIcon(R.drawable.ic_on_call)
                .setContentTitle(displayName)
                .setContentText(notificationTitle)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setWhen(System.currentTimeMillis())
                .setAutoCancel(false)
                .setShowWhen(true)
                .setOngoing(true)
                .setColor(ContextCompat.getColor(context, R.color.notification_led_color))
                .setFullScreenIntent(pendingIntent, true)
                .addAction(notificationsManager.getCallDeclineAction(notifiable))
                .addAction(notificationsManager.getCallAnswerAction(notifiable))
                .setCustomHeadsUpContentView(notificationLayoutHeadsUp)
            pic = null
            return notificationBuilder.build()
        }

        fun createCallNotification (
            context: Context,
            call: Call,
            notifiable: Notifiable,
            pendingIntent: PendingIntent,
            notificationsManager: NotificationsManager,
        ) : Notification{
            val callerNumber = FMUtils.getPhoneNumber(call.remoteAddress)
            val formattedCallerNumber = PhoneNumberUtils.formatNumber(callerNumber,"US")
            val contact:Contact? = NotificationsManager.contacts[callerNumber]

            val callerAvatar: String = contact?.avatar ?: ""
            val title= contact?.name ?: formattedCallerNumber
            if(callerAvatar.isNotEmpty()){
                runBlocking {
                    pic = getImage(URL(callerAvatar))
                }
            }

            var contactAvatar: IconCompat = IconCompat.createWithResource(
                context,
                R.drawable.blank_avatar
            )

            pic?.let {it
                contactAvatar = IconCompat.createWithBitmap(it)
            }

            val icon:Bitmap = BitmapFactory.decodeResource(context.resources, R.drawable.blank_avatar)

            val person: Person = Person.Builder()
                .setName(title)
                .setIcon(contactAvatar)
                .build()
            val notificationText:String = when (call.state) {
                Call.State.Pausing, Call.State.Paused ->{
                    "Call on hold - $formattedCallerNumber"
                }
                else -> {
                    "Call in progress - $formattedCallerNumber"
                }
            }
            val smallIcon = when (call.state) {
                Call.State.Paused, Call.State.Pausing -> {
                    R.drawable.ic_call_on_hold
                } else -> {
                    R.drawable.ic_on_call
                }
            }
            val notificationBuilder: NotificationCompat.Builder =
                NotificationCompat.Builder(
                        context,
                        context.getString(R.string.notification_channel_call_service_id)
                    )
                    .setContentTitle(title)
                    .setContentText(notificationText)
                    .setSmallIcon(smallIcon)
                    .setLargeIcon(icon)
                    .addPerson(person)
                    .setAutoCancel(false)
                    .setCategory(NotificationCompat.CATEGORY_CALL)
                    .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setWhen(System.currentTimeMillis())
                    .setShowWhen(true)
                    .setColor(ContextCompat.getColor(context, R.color.notification_led_color))
                    .addAction(notificationsManager.getCallDeclineAction(notifiable, true))
            pic = null
            return  notificationBuilder.build()
        }
    }
}
