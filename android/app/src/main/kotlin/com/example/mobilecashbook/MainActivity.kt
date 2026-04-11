package com.example.mobilecashbook

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "mobilecashbook/sms_events"
    private var methodChannel: MethodChannel? = null

    private val smsBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != "com.example.mobilecashbook.NEW_SMS") return

            val from = intent.getStringExtra("from") ?: ""
            val body = intent.getStringExtra("body") ?: ""
            val smsDate = intent.getStringExtra("smsDate") ?: ""

            val payload = mapOf(
                "from" to from,
                "body" to body,
                "smsDate" to smsDate
            )

            methodChannel?.invokeMethod("onSmsReceived", payload)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter("com.example.mobilecashbook.NEW_SMS")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsBroadcastReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(smsBroadcastReceiver, filter)
        }
    }

    override fun onStop() {
        unregisterReceiver(smsBroadcastReceiver)
        super.onStop()
    }
}