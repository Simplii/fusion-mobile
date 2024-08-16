package net.fusioncomm.android

import android.app.Application
import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class FusionMobileApplication : Application() {

    companion object {
        private const val debugTag = "MDBM FMApplication"
        lateinit var fmCore: FMCore
        lateinit var engine : FlutterEngine
        lateinit var callingChannel: MethodChannel
        lateinit var contactsChannel: MethodChannel
        lateinit var callEventChannel: EventChannel
        fun ensureCoreExists(
            context: Context,
            skipCoreStart: Boolean = false
        ): Boolean {
            // this func will return whether core was created not no

            if (::fmCore.isInitialized && FMCore.coreStarted) {
                Log.d( debugTag, "Skipping Core creation")
                return false
            }

            Log.d(
                "MDBM FMApplication",
                "Core context is being created..."
            )
            fmCore = FMCore(
                context,
                callingChannel
            )
//            if (!skipCoreStart) {
//                coreContext.start()
//            }
            return true
        }

        fun contextExists(): Boolean {
            return ::fmCore.isInitialized
        }

    }
    override fun onCreate() {
        super.onCreate()
        Log.d(debugTag, "Application is being created")

        // Instantiate a FlutterEngine.
        engine = FlutterEngine(this)

        // Start executing Dart code to pre-warm the FlutterEngine.
        callingChannel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "net.fusioncomm.android/calling"
        );

        callEventChannel = EventChannel(
            engine.dartExecutor.binaryMessenger,
            "channel/callInfo"
        )

        contactsChannel = MethodChannel(
            FusionMobileApplication.engine.dartExecutor.binaryMessenger,
            "net.fusioncomm.ios/contacts"
        )

        fmCore = FMCore(applicationContext, callingChannel)

        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        FlutterEngineCache
            .getInstance()
            .put("fusion_flutter_engine", engine)

    }
}