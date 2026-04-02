package com.example.mobilecashbook

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telephony.SmsMessage
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import java.util.concurrent.TimeUnit
import androidx.work.BackoffPolicy

class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return

        val bundle: Bundle = intent.extras ?: return
        val pdus = bundle.get("pdus") as? Array<*> ?: return
        val format = bundle.getString("format")

        for (pdu in pdus) {
            val sms = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                SmsMessage.createFromPdu(pdu as ByteArray, format)
            } else {
                @Suppress("DEPRECATION")
                SmsMessage.createFromPdu(pdu as ByteArray)
            }

            val body = sms.messageBody ?: ""
            val from = sms.originatingAddress ?: ""
            val timestamp = sms.timestampMillis

            val smsDate = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
                .format(Date(timestamp))

            val deviceId = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ANDROID_ID
            ) ?: "unknown-device"

            val smsData = mapOf(
                "localId" to UUID.randomUUID().toString(),
                "deviceId" to deviceId,
                "from" to from,
                "body" to body,
                "smsDate" to smsDate,
                "providerHint" to detectProvider(from, body)
            )

            SmsStore.enqueue(context, smsData)
        }

        enqueueForwardWorker(context)
    }

    private fun enqueueForwardWorker(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val work = OneTimeWorkRequestBuilder<SmsForwardWorker>()
            .setConstraints(constraints)
            .setBackoffCriteria(
                BackoffPolicy.EXPONENTIAL,
                15,
                TimeUnit.SECONDS
            )
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            "sms-forward-work",
            ExistingWorkPolicy.KEEP,
            work
        )
    }

    private fun detectProvider(from: String, body: String): String {
        val source = "$from $body".lowercase()
        return when {
            source.contains("airtel") || source.contains("myairtel") -> "airtel"
            source.contains("mtn") || source.contains("momo") -> "mtn"
            else -> "unknown"
        }
    }
}