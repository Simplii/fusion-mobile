package net.fusioncomm.android.http

import android.util.Log
import org.chromium.net.UploadDataProvider
import org.chromium.net.UploadDataSink
import java.io.File
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets

/*  
    Created by Zaid Jamil.
*/

private const val TAG = "MDBM FMUploadDataProvider"

class FMUploadDataProvider(private val data: File): UploadDataProvider() {
    override fun getLength(): Long {
        val size:Long = data.length()
        Log.e(TAG, "Length = $size")
        return size
    }

    override fun read(uploadDataSink: UploadDataSink?, byteBuffer: ByteBuffer?) {
        Log.e(TAG,"READ IS CALLED")
        byteBuffer?.put(data.readBytes(), 0, data.length().toInt())
        uploadDataSink?.onReadSucceeded(true)
    }

    override fun rewind(uploadDataSink: UploadDataSink?) {
        Log.e(TAG,"REWIND IS CALLED")
        uploadDataSink?.onRewindSucceeded()
    }
}