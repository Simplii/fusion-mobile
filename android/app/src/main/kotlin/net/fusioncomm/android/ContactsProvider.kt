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
    private val contactsChannel = FusionMobileApplication.contactsChannel

    init {
            Log.d(debugTag,"contacts provider channel created")
            contactsChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncContacts" -> {
                        ContactsThread(contactsChannel, contentResolver, context).start()
                    }
                    "sync" -> {
                        ContactsThread(contactsChannel, contentResolver, context).syncNew()
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}