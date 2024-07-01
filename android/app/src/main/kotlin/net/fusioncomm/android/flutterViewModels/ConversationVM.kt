package net.fusioncomm.android.flutterViewModels

import android.content.Context
import android.os.Build
import android.util.Log
import android.view.textclassifier.TextClassificationManager
import android.view.textclassifier.TextClassifier
import android.view.textclassifier.TextLinks
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import net.fusioncomm.android.FusionMobileApplication

/*  
    Created by Zaid Jamil.
*/
class ConversationVM(context: Context) {
    val DEBUG_TAG = "MDBM FlutterConversationVM"
    private val textClassificationManager = context.getSystemService(Context.TEXT_CLASSIFICATION_SERVICE) as TextClassificationManager
    private val textClassifier: TextClassifier = textClassificationManager.textClassifier
    init {
        var conversationVMMethodConversationVM: MethodChannel? = null
        val engine: FlutterEngine? = FlutterEngineCache
            .getInstance()
            .get("fusion_flutter_engine")

        if (engine != null) {
            conversationVMMethodConversationVM = MethodChannel(
                FusionMobileApplication.engine.dartExecutor.binaryMessenger,
                "channel/conversations"
            )
        }

        conversationVMMethodConversationVM?.setMethodCallHandler { call, result ->
            when (call.method) {
                "detectAddress" -> {
//                    Log.d(DEBUG_TAG, "${call.arguments}")
                    val args = call.arguments as ArrayList<String>
                    var ret = ""
                    runBlocking {
                        ret = getAddressLink(args[0])
                    }
                    result.success(ret)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private suspend fun getAddressLink(text:String):String {
        var t = text
        if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q){
            CoroutineScope(Dispatchers.IO).async {
                var links =  textClassifier.generateLinks(
                    TextLinks.Request.Builder(t)
                        .setEntityConfig(
                            TextClassifier.EntityConfig.Builder()
                                .setIncludedTypes(
                                    arrayListOf(TextClassifier.TYPE_ADDRESS)
                                )
                                .includeTypesFromTextClassifier(false)
                                .build()
                        )
                        .build()
                )
                for (link in links.links) {
                    val address = t.substring(link.start, link.end)
                    t = t.replaceRange(
                        link.start,
                        link.end,
                        "https://maps.google.com/?q=${address.replace(" ", "+").replace(",","")}"
                    )
                }
            }.await()
        }
        return t
    }
}