package com.example.mobilecashbook

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object SmsStore {
    private const val PREFS = "sms_forward_store"
    private const val KEY_QUEUE = "queue"

    fun enqueue(context: Context, payload: Map<String, String>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString(KEY_QUEUE, "[]"))

        val obj = JSONObject()
        payload.forEach { (k, v) -> obj.put(k, v) }
        obj.put("sent", false)
        obj.put("tries", 0)

        arr.put(obj)
        prefs.edit().putString(KEY_QUEUE, arr.toString()).apply()
    }

    fun getPending(context: Context): MutableList<JSONObject> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString(KEY_QUEUE, "[]"))
        val list = mutableListOf<JSONObject>()

        for (i in 0 until arr.length()) {
            val obj = arr.getJSONObject(i)
            if (!obj.optBoolean("sent", false)) {
                list.add(obj)
            }
        }

        return list
    }

    fun markSent(context: Context, localId: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString(KEY_QUEUE, "[]"))

        for (i in 0 until arr.length()) {
            val obj = arr.getJSONObject(i)
            if (obj.optString("localId") == localId) {
                obj.put("sent", true)
            }
        }

        prefs.edit().putString(KEY_QUEUE, arr.toString()).apply()
    }

    fun incrementTry(context: Context, localId: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString(KEY_QUEUE, "[]"))

        for (i in 0 until arr.length()) {
            val obj = arr.getJSONObject(i)
            if (obj.optString("localId") == localId) {
                obj.put("tries", obj.optInt("tries", 0) + 1)
            }
        }

        prefs.edit().putString(KEY_QUEUE, arr.toString()).apply()
    }
}