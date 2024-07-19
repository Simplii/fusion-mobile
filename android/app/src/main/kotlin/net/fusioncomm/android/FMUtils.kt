package net.fusioncomm.android

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import net.fusioncomm.android.http.Multipart
import org.linphone.core.Address
import org.linphone.core.Headers
import java.io.File
import java.io.PrintWriter
import java.net.URL
import java.math.BigInteger
import java.net.HttpURLConnection
import java.security.MessageDigest
import java.security.Signature

class FMUtils {
    companion object {
        private const val TAG = "MDBM FMUtils"
        fun getDisplayName(address: Address?): String {
            if (address == null) return "[null]"
            if (address.displayName == null) {
                val account = FMCore.core.accountList.find { account ->
                    account.params.identityAddress?.asStringUriOnly() == address.asStringUriOnly()
                }
                val localDisplayName = account?.params?.identityAddress?.displayName
                // Do not return an empty local display name
                if (!localDisplayName.isNullOrEmpty()) {
                    return localDisplayName
                }
            }
            // Do not return an empty display name
            return address.displayName ?: address.username ?: address.asString()
        }

        fun getPhoneNumber(address: Address?): String {
            if(address == null) return ""
            val cleanSip: String = address.asStringUriOnly().replace("sip:", "")
            return cleanSip.substring(0, cleanSip.indexOf("@"))
        }

        fun sendLogsToServer(
            logsFile: File,
            truncateFile:Boolean = false,
            deleteFile:Boolean = false,
            context: Context,
            retryCount: Int = 0,
            newSignature: String? = null
        ) {
            val flutterSharedPref: SharedPreferences = context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE
            )
            val username = flutterSharedPref.getString("flutter.username", "") ?: ""
            val token = flutterSharedPref.getString("flutter.token", "") ?: ""
            val signature = newSignature ?: flutterSharedPref.getString("flutter.signature", "") ?: ""
            val md = MessageDigest.getInstance("MD5")
            val hashBytes = md.digest("$token:$username:/api/v2/logging/log::$signature".toByteArray())
            val authToken = hashBytes.joinToString("") { "%02x".format(it) }
            val requestHeaders = arrayOf(
                mapOf(Pair("X-fusion-uid", username)),
                mapOf(Pair("Authorization", "Bearer $authToken")),
            )
            val req = Multipart(
                URL("https://zaid-fusion-dev.fusioncomm.net/api/v2/logging/log"),
                requestHeaders
            )
            req.addFormField("username", username)
            req.addFilePart("fm_logs6695503dca9ca",logsFile,"logs","txt")
            req.addHeaderField("Content-Type","multipart/form-data")
            val fileUploadListener = object: Multipart.OnFileUploadedListener {
                override fun onFileUploadingSuccess(response: String) {
                    Log.d(TAG, "upload resp = $response")
                    Log.d(TAG, "file size = ${logsFile.length()}")
                    if (truncateFile) {
                        val writer = PrintWriter(logsFile)
                        writer.print("")
                        writer.close()
                    }

                    if (deleteFile) {
                        logsFile.delete()
                    }

                    Log.d(TAG, "file size after upload = ${logsFile.length()}")
                }
                override fun onFileUploadingFailed(responseCode: Int, headers: Map<String,List<String>>?) {
                    if(responseCode == 401) {
                        val newSignature: List<String> = headers?.get("x-fusion-signature") ?: listOf()
                        if(retryCount < 5 && newSignature.isNotEmpty()) {
                            Log.d(TAG, "newSig $newSignature")
                            sendLogsToServer(logsFile, truncateFile, deleteFile, context, retryCount + 1, newSignature.first())
                        } else {
                            Log.e(TAG, if(newSignature.isNotEmpty())
                                "upload fail after retrying to authorize 5 times"
                                else "New signature was not available"
                            )
                        }
                    } else {
                        Log.e(TAG, "upload fail statuscode = $responseCode")
                    }
                }
            }
            req.upload(fileUploadListener)
        }
    }
}