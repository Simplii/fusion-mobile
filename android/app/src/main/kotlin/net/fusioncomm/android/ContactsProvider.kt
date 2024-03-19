package net.fusioncomm.android

import android.content.ContentResolver
import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel


class ContactsProvider(context: Context) {
    private val debugTag = "MDBM ContactsProvider"
    private val contentResolver:ContentResolver = context.contentResolver
    init {
        var contactsChannel: MethodChannel? = null
        val engine: FlutterEngine? = FlutterEngineCache
            .getInstance()
            .get("fusion_flutter_engine")

        if (engine != null) {
            contactsChannel = MethodChannel(
                FusionMobileApplication.engine.dartExecutor.binaryMessenger,
                "net.fusioncomm.ios/contacts"
            )
        }
        if (contactsChannel == null) {
            Log.d(debugTag,"Coludn't create contacts provider channel")
        } else {
            Log.d(debugTag,"contacts provider channel created")
            contactsChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncContacts" -> {
                        ContactsThread(contactsChannel, contentResolver).start()
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }
}