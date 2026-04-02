package com.example.mobilecashbook

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class SmsForwardWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    private val client = OkHttpClient()

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val pending = SmsStore.getPending(applicationContext)
        if (pending.isEmpty()) {
            return@withContext Result.success()
        }

        val mediaType = "application/json; charset=utf-8".toMediaType()

        try {
            for (item in pending) {
                val localId = item.optString("localId")
                SmsStore.incrementTry(applicationContext, localId)

                val payload = JSONObject().apply {
                    put("DeviceId", item.optString("deviceId"))
                    put("From", item.optString("from"))
                    put("Body", item.optString("body"))
                    put("SmsDate", item.optString("smsDate"))
                    put("ProviderHint", item.optString("providerHint"))
                }

                val request = Request.Builder()
                    .url("https://mobile.smbet.info/api/MobileMoneySms/ForwardedSms")
                    .addHeader("Content-Type", "application/json")
                    .post(payload.toString().toRequestBody(mediaType))
                    .build()

                client.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        SmsStore.markSent(applicationContext, localId)
                    } else {
                        return@withContext Result.retry()
                    }
                }
            }

            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}