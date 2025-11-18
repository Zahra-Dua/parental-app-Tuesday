package com.example.parental_control_app

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "child_tracking"
    private var childTrackingChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register all plugins
        flutterEngine.plugins.add(UrlTrackingPlugin())
        flutterEngine.plugins.add(AppListPlugin())
        flutterEngine.plugins.add(UsageStatsPlugin())
        
        // Set up child_tracking method channel
        childTrackingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Set the child_tracking channel for UrlAccessibilityService
        UrlAccessibilityService.setChildTrackingChannel(childTrackingChannel!!)
        
        childTrackingChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsageStatsPermission" -> {
                    result.success(checkUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    requestUsageStatsPermission()
                    result.success(true)
                }
                "checkAccessibilityPermission" -> {
                    result.success(checkAccessibilityPermission())
                }
                "requestAccessibilityPermission" -> {
                    requestAccessibilityPermission()
                    result.success(true)
                }
                "startUrlTracking" -> {
                    startUrlTracking()
                    result.success(true)
                }
                "startAppUsageTracking" -> {
                    startAppUsageTracking()
                    result.success(true)
                }
                "stopAllTracking" -> {
                    stopAllTracking()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsageStatsPermission() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun checkAccessibilityPermission(): Boolean {
        val accessibilityManager = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        )
        return enabledServices?.contains("${packageName}/${UrlAccessibilityService::class.java.name}") == true
    }

    private fun requestAccessibilityPermission() {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }

    private fun startUrlTracking() {
        // Start accessibility service for URL tracking
        val intent = Intent(this, UrlAccessibilityService::class.java)
        startService(intent)
    }

    private fun startAppUsageTracking() {
        // Start app usage monitoring
        // This will be handled by the accessibility service
    }

    private fun stopAllTracking() {
        // Stop all tracking services
        val intent = Intent(this, UrlAccessibilityService::class.java)
        stopService(intent)
    }
}
