package com.h4cks1lv3.iron_cadence

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val preferences = getSharedPreferences("iron_cadence", MODE_PRIVATE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "iron_cadence/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> result.success(preferences.getString("state", null))
                    "write" -> {
                        preferences.edit().putString("state", call.arguments as? String ?: "{}").apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
