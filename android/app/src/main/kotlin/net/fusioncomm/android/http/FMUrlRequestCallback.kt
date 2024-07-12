package net.fusioncomm.android.http

import android.util.Log
import org.chromium.net.CronetException
import org.chromium.net.UrlRequest
import java.nio.ByteBuffer

/*
    Created by Zaid Jamil.
*/

private const val TAG = "MDBM FMUrlRequestCallback"

class FMUrlRequestCallback : UrlRequest.Callback() {
    override fun onRedirectReceived(
        request: UrlRequest?,
        info: org.chromium.net.UrlResponseInfo?,
        newLocationUrl: String?
    ) {
        Log.i(TAG, "onRedirectReceived method called.")
        // You should call the request.followRedirect() method to continue
        // processing the request.
        request?.followRedirect()
    }

    override fun onResponseStarted(request: UrlRequest?, info: org.chromium.net.UrlResponseInfo?) {
        Log.i(TAG, "onResponseStarted method called.")
        request?.read(ByteBuffer.allocateDirect(102400))
    }

    override fun onReadCompleted(
        request: UrlRequest?,
        info: org.chromium.net.UrlResponseInfo?,
        byteBuffer: ByteBuffer?
    ) {
        Log.i(TAG, "onReadCompleted method called.")
        // You should keep reading the request until there's no more data.
        byteBuffer?.clear()
        request?.read(byteBuffer)
    }

    override fun onSucceeded(request: UrlRequest?, info: org.chromium.net.UrlResponseInfo?) {
        Log.i(TAG, "onSucceeded method called.")
        Log.d(TAG, "headers ${info?.allHeaders}")
        Log.d(TAG, "headers ${info?.url}")
        Log.d(TAG, "headers ${info?.httpStatusCode}")
    }

    override fun onFailed(
        request: UrlRequest?,
        info: org.chromium.net.UrlResponseInfo?,
        error: CronetException?
    ) {
        Log.e(TAG, "onFailed method called. $info ${error?.message}")

    }

}