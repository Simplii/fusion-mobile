package net.fusioncomm.android.compatibility

import android.app.Activity
import android.view.WindowManager

class Api23Compatibility {
    companion object {

        fun setTurnScreenOn(activity: Activity, enable: Boolean) {
            if (enable) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            }
        }

        fun requestDismissKeyguard(activity: Activity) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
        }

        fun setShowWhenLocked(activity: Activity, enable: Boolean) {
            if (enable) {
                activity.window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            } else {
                activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
            }
        }

    }
}