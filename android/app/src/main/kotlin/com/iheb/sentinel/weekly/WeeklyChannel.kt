package com.iheb.sentinel.weekly

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Canal du bilan de la semaine (lib/services/weekly_report_service.dart).
 * N'accepte que des clés de la liste fermée et des nombres.
 */
class WeeklyChannel(context: Context, messenger: BinaryMessenger) {
    private val app = context.applicationContext

    init {
        MethodChannel(messenger, "com.iheb.sentinel/weekly").setMethodCallHandler { call, result ->
            when (call.method) {
                "count" -> {
                    val key = call.argument<String>("key").orEmpty()
                    val n = call.argument<Number>("n")?.toLong() ?: 1L
                    WeeklyStatsStore.count(app, key, n)
                    WeeklyStatsStore.flush(app)
                    result.success(null)
                }
                "setGauge" -> {
                    val key = call.argument<String>("key").orEmpty()
                    val value = call.argument<Number>("value")?.toInt() ?: -1
                    WeeklyStatsStore.setGauge(app, key, value)
                    result.success(null)
                }
                "recordScore" -> {
                    WeeklyStatsStore.recordScore(app, call.argument<Number>("score")?.toInt() ?: -1)
                    result.success(null)
                }
                "snapshot" -> result.success(WeeklyStatsStore.snapshot(app))
                "getNotificationsEnabled" -> result.success(WeeklyStatsStore.notificationsEnabled(app))
                "setNotificationsEnabled" -> {
                    WeeklyStatsStore.setNotificationsEnabled(app, call.argument<Boolean>("enabled") == true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
