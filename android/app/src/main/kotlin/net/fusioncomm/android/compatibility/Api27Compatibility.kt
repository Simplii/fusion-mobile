package net.fusioncomm.android.compatibility

import android.annotation.TargetApi
import android.app.Activity
import android.app.KeyguardManager
import android.content.Context

@TargetApi(27)
class Api27Compatibility {
    companion object {

        fun setTurnScreenOn(activity: Activity, enable: Boolean) {
            activity.setTurnScreenOn(enable)
        }

        fun requestDismissKeyguard(activity: Activity) {
            val keyguardManager = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(activity, null)
        }

        fun setShowWhenLocked(activity: Activity, enable: Boolean) {
            activity.setShowWhenLocked(enable)
        }

    }
}