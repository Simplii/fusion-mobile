package net.fusioncomm.android.notifications

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import net.fusioncomm.android.FMCore
import net.fusioncomm.android.services.FusionCallService
import org.linphone.core.Call

class NotificationsBroadcastReceiver: BroadcastReceiver()  {
    private val  debugTag = "MDBM NotificationBR"

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(debugTag,"Ensuring Core exists")
        if(FMCore.coreStarted){
            val notificationId = intent.getIntExtra(NotificationsManager.INTENT_NOTIF_ID, 0)
            Log.d( debugTag,
                "Got notification broadcast for ID [$notificationId]"
            )

            if (intent.action == NotificationsManager.INTENT_REPLY_NOTIF_ACTION ||
                intent.action == NotificationsManager.INTENT_MARK_AS_READ_ACTION) {

                // TODO:: handleChatIntent to replay/interact from chat notification

            } else if (intent.action == NotificationsManager.INTENT_ANSWER_CALL_NOTIF_ACTION ||
                intent.action == NotificationsManager.INTENT_HANGUP_CALL_NOTIF_ACTION ||
                intent.action == NotificationsManager.INTENT_UNHOLD_CALL_NOTIF_ACTION) {
                handleCallIntent(intent, context, notificationId)
            }
        } else {
            Log.d(debugTag,"Core not ready")
        }

    }

    private fun handleCallIntent(intent: Intent, context: Context, notificationId: Int) {
        val callUUID = intent.getStringExtra(NotificationsManager.INTENT_CALL_UUID)
        if (callUUID == null) {
            Log.d("MDBM Notification BR","Call uuid is null for notification")
            return
        }
        val call: Call? = FMCore.callsManager.findCallByUuid(callUUID)
        if (call == null) {
            Log.d(
                "MDBM Notification BR",
                "Couldn't find call from uuid $callUUID"
            )
            return
        }
        Log.d(
            "MDBM Notification BR",
            "intent action ${intent.action.toString()}"
        )
        if (intent.action == NotificationsManager.INTENT_ANSWER_CALL_NOTIF_ACTION) {
            Log.d(
                "MDBM Notification BR",
                "Answer call"
            )
            // to have access to microphone while app in the background in Android 14 and up
            // we must start a foregroundService with type mic, but we can't start a foregroundService
            // that needs while-in-use permission unless it falls in one of the exemptions ref#
            // https://developer.android.com/develop/background-work/services/foreground-services#bg-access-restrictions
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // here we're tackling this exemption, The user performs an action on a UI element related to your app.
                // Since we know the user has tapped on callStyle notification to get here
                val intent = Intent(context, FusionCallService::class.java)
                intent.putExtra(NotificationsManager.INTENT_NOTIF_ID, notificationId)
                intent.putExtra("AnswerCall", true)
                context.startForegroundService(intent)
                NotificationsManager.callServiceStartedFormBR = true
            }
            //FIXME:: call need to be answered after the service start
//            call.accept()
        } else if (intent.action == NotificationsManager.INTENT_UNHOLD_CALL_NOTIF_ACTION) {
            Log.d(debugTag, "unhold call")
            FMCore.callsManager.resumeCall(call)
        } else {
            if (call.state == Call.State.IncomingReceived ||
                call.state == Call.State.IncomingEarlyMedia
            ) {
                Log.d(
                    "MDBM Notification BR",
                    "decline incoming call"
                )
//                call.decline(Reason.Busy) supposed to be like this, but our proxy won't recognize it
                call.terminate()
            } else {
                Log.d(
                    "MDBM Notification BR",
                    "terminate ongoing call ${FMCore.core.isInBackground}"
                )
                call.terminate()
            }
        }
    }

//    private fun handleChatIntent(context: Context, intent: Intent, notificationId: Int) {
//        val remoteSipAddress = intent.getStringExtra(NotificationsManager.INTENT_REMOTE_ADDRESS)
//        if (remoteSipAddress == null) {
//            Log.e(
//                    "[Notification Broadcast Receiver] Remote SIP address is null for notification id $notificationId"
//            )
//            return
//        }
//        val core: Core = coreContext.core
//
//        val remoteAddress = core.interpretUrl(remoteSipAddress, false)
//        if (remoteAddress == null) {
//            Log.e(
//                    "[Notification Broadcast Receiver] Couldn't interpret remote address $remoteSipAddress"
//            )
//            return
//        }
//
//        val localIdentity = intent.getStringExtra(NotificationsManager.INTENT_LOCAL_IDENTITY)
//        if (localIdentity == null) {
//            Log.e(
//                    "[Notification Broadcast Receiver] Local identity is null for notification id $notificationId"
//            )
//            return
//        }
//        val localAddress = core.interpretUrl(localIdentity, false)
//        if (localAddress == null) {
//            Log.e(
//                    "[Notification Broadcast Receiver] Couldn't interpret local address $localIdentity"
//            )
//            return
//        }
//
//        val room = core.searchChatRoom(null, localAddress, remoteAddress, arrayOfNulls(0))
//        if (room == null) {
//            Log.e(
//                    "[Notification Broadcast Receiver] Couldn't find chat room for remote address $remoteSipAddress and local address $localIdentity"
//            )
//            return
//        }
//
//        if (intent.action == NotificationsManager.INTENT_REPLY_NOTIF_ACTION) {
//            val reply = getMessageText(intent)?.toString()
//            if (reply == null) {
//                Log.e("[Notification Broadcast Receiver] Couldn't get reply text")
//                return
//            }
//
//            val msg = room.createMessageFromUtf8(reply)
//            msg.userData = notificationId
//            msg.addListener(coreContext.notificationsManager.chatListener)
//            msg.send()
//            Log.d("MDBM","[Notification Broadcast Receiver] Reply sent for notif id $notificationId")
//        } else {
//            room.markAsRead()
//            if (!coreContext.notificationsManager.dismissChatNotification(room)) {
//                Log.w(
//                        "[Notification Broadcast Receiver] Notifications Manager failed to cancel notification"
//                )
//                val notificationManager = context.getSystemService(NotificationManager::class.java)
//                notificationManager.cancel(NotificationsManager.CHAT_TAG, notificationId)
//            }
//        }
//    }
}