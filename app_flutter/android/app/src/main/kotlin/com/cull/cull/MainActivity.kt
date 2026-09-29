package com.cull.cull

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedUrl" -> result.success(pendingUrl)
                    "consumeSharedUrl" -> {
                        pendingUrl = null
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        pendingUrl = urlFrom(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingUrl = urlFrom(intent)
    }

    private var pendingUrl: String? = null

    private fun urlFrom(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action != Intent.ACTION_SEND) return null
        if (intent.type?.startsWith("text/") != true) return null
        val shared = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
        return shared.trim().substringAfter("url=", shared.trim()).trim()
    }

    companion object {
        private const val CHANNEL = "com.cull.cull/share"
    }
}
