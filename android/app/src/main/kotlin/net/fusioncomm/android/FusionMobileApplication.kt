package net.fusioncomm.android

import android.app.Application
import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class FusionMobileApplication : Application() {
    companion object {
        lateinit var engine : FlutterEngine
        lateinit var callingChannel: MethodChannel

    }
    override fun onCreate() {
        super.onCreate()
        Log.d("MDBM Application", "Application is being created")
        // Instantiate a FlutterEngine.
        engine = FlutterEngine(this)
        // Start executing Dart code to pre-warm the FlutterEngine.
        callingChannel = MethodChannel(
            engine.dartExecutor.binaryMessenger,
            "net.fusioncomm.android/calling"
        );
        FMCore(applicationContext, callingChannel)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        FlutterEngineCache
            .getInstance()
            .put("my_engine_id", engine)

        // here we can initialize linphoneCore to make sure it is running if aap was launched
        // form a service or activity
    }

//    private fun set()
}