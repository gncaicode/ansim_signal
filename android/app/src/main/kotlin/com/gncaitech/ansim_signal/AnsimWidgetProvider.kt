package com.gncaitech.ansim_signal

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import java.util.Calendar

/**
 * 안심시그널 소형 홈 위젯 (2×2).
 * FlutterSharedPreferences에서 체크인 데이터를 직접 읽어 표시.
 */
class AnsimWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id, isSmall = true)
        }
    }

    companion object {
        private const val TAG = "AnsimWidget"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int,
            isSmall: Boolean
        ) {
            try {
                val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                val lastMs = prefs.getLong("flutter.last_check_in", 0L)
                val intervalHours = prefs.getLong("flutter.interval_hours", 24L)

                val now = System.currentTimeMillis()
                val deadline = lastMs + intervalHours * 3_600_000L
                val remainingMs = deadline - now

                val status = when {
                    lastMs == 0L -> "unknown"
                    remainingMs < 0 -> "overdue"
                    remainingMs < intervalHours * 3_600_000L / 12 -> "warning"
                    else -> "safe"
                }

                val dotDrawable = when (status) {
                    "safe" -> R.drawable.widget_dot_safe
                    "warning" -> R.drawable.widget_dot_warning
                    "overdue" -> R.drawable.widget_dot_overdue
                    else -> R.drawable.widget_dot_unknown
                }
                val statusLabel = when (status) {
                    "safe" -> "안전"
                    "warning" -> "주의"
                    "overdue" -> "위급"
                    else -> "미확인"
                }

                val lastCheckinStr = if (lastMs == 0L) "--" else formatTime(lastMs)
                val timeRemainingStr = formatRemaining(remainingMs, status)

                // 버튼 탭 → 백그라운드 체크인
                val checkinIntent = Intent(context, WidgetCheckinReceiver::class.java).apply {
                    action = "com.gncaitech.ansim_signal.WIDGET_CHECKIN"
                }
                val checkinPendingIntent = PendingIntent.getBroadcast(
                    context, widgetId * 10, checkinIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                // 버튼 밖 탭 → 앱 열기
                val appIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val appPendingIntent = PendingIntent.getActivity(
                    context, widgetId * 10 + 1, appIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val layout = if (isSmall) R.layout.widget_small else R.layout.widget_medium
                val rv = RemoteViews(context.packageName, layout)

                rv.setImageViewResource(R.id.widget_status_dot, dotDrawable)

                if (isSmall) {
                    rv.setTextViewText(R.id.widget_time_remaining, timeRemainingStr)
                } else {
                    rv.setTextViewText(R.id.widget_status_text, statusLabel)
                    rv.setTextViewText(R.id.widget_last_checkin, "마지막: $lastCheckinStr")
                    rv.setTextViewText(R.id.widget_time_remaining, timeRemainingStr)
                }

                rv.setOnClickPendingIntent(R.id.widget_root, appPendingIntent)
                rv.setOnClickPendingIntent(R.id.widget_button, checkinPendingIntent)
                appWidgetManager.updateAppWidget(widgetId, rv)

            } catch (e: Exception) {
                Log.e(TAG, "위젯 업데이트 오류", e)
            }
        }

        private fun formatTime(ms: Long): String {
            val cal = Calendar.getInstance().apply { timeInMillis = ms }
            val hour = cal.get(Calendar.HOUR_OF_DAY)
            val minute = cal.get(Calendar.MINUTE)
            val period = if (hour < 12) "오전" else "오후"
            val h = when {
                hour == 0 -> 12
                hour > 12 -> hour - 12
                else -> hour
            }
            return "$period $h:${minute.toString().padStart(2, '0')}"
        }

        private fun formatRemaining(remainingMs: Long, status: String): String {
            if (status == "unknown") return "신호 없음"
            if (remainingMs < 0) {
                val hours = (-remainingMs / 3_600_000L).toInt()
                return if (hours > 0) "${hours}시간 초과" else "초과됨"
            }
            val hours = (remainingMs / 3_600_000L).toInt()
            if (hours >= 1) return "${hours}시간 남음"
            val minutes = (remainingMs / 60_000L).toInt()
            return "${minutes}분 남음"
        }
    }
}
