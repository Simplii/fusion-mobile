package net.fusioncomm.android.services

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import net.fusioncomm.android.notifications.Contact
import net.fusioncomm.android.notifications.NotificationsManager

class FirebaseMessagingService : FirebaseMessagingService() {
    private val TAG = "MDBM FirebsaseMS"

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "TODO handle token change")
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d(TAG, "data: ${remoteMessage.data}")
        Log.d(TAG, "notification: ${remoteMessage.notification}")

        // Check if message contains a data payload.
        if (remoteMessage.data.isNotEmpty()) {
            //if its a call then ensure linCore is ready if not create it then create
            //the notification
            if (remoteMessage.data.containsKey("fusion_call")) {
                val callerNumber = remoteMessage.data["caller_number"] ?: ""
                val callerName = remoteMessage.data["caller_id"] ?: "NoName"
                val callerAvatar = remoteMessage.data["avatar"] ?: ""
                val callId = remoteMessage.data["call_id"] ?: ""

                val contact = Contact(callerName, callerNumber, callerAvatar)
                NotificationsManager.contact = contact
                NotificationsManager.incomingNotification = true
                Log.d(TAG, "$callerNumber $callerName $callerAvatar $callId")
            }
        }


        // Check if message contains a notification payload.
        remoteMessage.notification?.let {
            Log.d(TAG, "Message Notification Body: ${it.body}")
        }
    }
}