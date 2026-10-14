package com.suivault.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Stage B: local_auth (biometric / device credential) requires
// FlutterFragmentActivity; plain FlutterActivity breaks it.
class MainActivity : FlutterFragmentActivity() {
    private val secureChannel = "com.suivault.app/secure"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // FLAG_SECURE: blocks screenshots, screen recording, and
                    // task-switcher thumbnails for this window. Used by the
                    // ID presentation page. Native one-liner — avoids the
                    // unmaintained flutter_windowmanager plugin, which
                    // breaks the release build on AGP 9+.
                    "enableSecure" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disableSecure" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
