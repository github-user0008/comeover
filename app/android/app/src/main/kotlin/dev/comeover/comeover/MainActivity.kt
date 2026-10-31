package dev.comeover.comeover

import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.comeover/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTelevision" -> {
                        val uiMode = resources.configuration.uiMode and Configuration.UI_MODE_TYPE_MASK
                        result.success(uiMode == Configuration.UI_MODE_TYPE_TELEVISION)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
