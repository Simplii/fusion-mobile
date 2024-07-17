package net.fusioncomm.android

import android.util.Log
import net.fusioncomm.android.http.Multipart
import org.linphone.core.Address
import java.io.File
import java.io.PrintWriter
import java.net.URL

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

        fun sendLogsToServer(logsFile: File, truncateFile:Boolean = false, deleteFile:Boolean = false) {
            val req = Multipart(
                URL("https://zaid-fusion-dev.fusioncomm.net/api/v2/logging/log")
            )
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
                override fun onFileUploadingFailed(responseCode: Int) {
                    Log.e(TAG, "upload fail statuscode = $responseCode")
                }
            }
            req.upload(fileUploadListener)
        }
    }
}