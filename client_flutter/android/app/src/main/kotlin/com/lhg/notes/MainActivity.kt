package com.lhg.notes

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
     private val DOWNLOAD_CHANNEL = "note123.download"
     private val DEVICE_INFO_CHANNEL = "device_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 下载功能的 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOAD_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "downloadWithSystem") {
                val url = call.argument<String>("url")
                if (url != null) {
                    val intent = Intent(Intent.ACTION_VIEW)
                    intent.data = Uri.parse(url)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(null)
                } else {
                    result.error("NO_URL", "URL is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
        
        // 设备信息的 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceType" -> {
                    val deviceType = getDeviceType()
                    result.success(deviceType)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun getDeviceType() = com.lhg.notes.BuildConfig.DEVICE_TYPE
}
