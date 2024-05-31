package net.fusioncomm.android.compatibility

import android.annotation.TargetApi
import android.content.Context
import android.os.OutcomeReceiver
import android.telecom.CallAudioState
import android.telecom.CallEndpoint
import android.util.Log
import androidx.core.content.ContextCompat
import net.fusioncomm.android.telecom.AudioRouteUtils
import net.fusioncomm.android.telecom.NativeCallWrapper

/*  
    Created by Zaid Jamil.
*/
@TargetApi(34)
class Api34Compatibility {
    companion object {
        const val DebugTag = "MDBM API34"
        fun changeAudioRouteForTelecomManager(
            connection: NativeCallWrapper,
            route: Int,
            context: Context,
            newEndpointType: Int
        ): Boolean {
            Log.d(
                DebugTag,
                "Changing audio route [${CallAudioState.audioRouteToString(route)}] on connection [${connection.callId}] with state [${connection.stateAsString()}]"
            )

            var currentEndpoint = connection.currentCallEndpoint

            Log.d(DebugTag,"Current call endpoint is ${currentEndpoint.endpointName}")

            val newEndpoint: CallEndpoint? = AudioRouteUtils.availableCallEndpoints.find {
                it.endpointType == newEndpointType
            }

            if (currentEndpoint.endpointType == route) {
                Log.d(DebugTag,"Connection is already using this route")
                return false
            }


            if (newEndpoint == null) {
                Log.e(DebugTag,"Did not find a match in AudioRouteUtils availableCallEndpoints")
                for (ep in AudioRouteUtils.availableCallEndpoints) {
                    Log.e(DebugTag,"${ep.endpointType} rout $route")
                }
                return false
            }

            connection.requestCallEndpointChange(newEndpoint, context.mainExecutor, OutcomeReceiver {
                    Log.d(DebugTag, "${it}")
                }
            )

            return true
        }
    }
}