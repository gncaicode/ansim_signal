package com.gncaitech.ansim_signal

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/**
 * 홈 위젯 체크인 버튼 탭 수신자.
 * WorkManager 없이 goAsync()로 직접 API 호출 → Samsung 배터리 최적화 우회.
 */
class WidgetCheckinReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WidgetCheckin"
        private const val API_URL = "http://ansim.gncaitech.com/api/checkin"
        private const val TOKEN_KEY = "ansim_server_token"
        // notification_service.dart의 scheduleExpirationReminder()가 쓰는 알림 ID(7)와 반드시 일치해야 함
        private const val EXPIRATION_REMINDER_NOTIFICATION_ID = 7
        private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        private var activeJob: Job? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()

        // 낙관적 업데이트: 버튼 탭 즉시 현재 시간으로 위젯 갱신
        val optimisticTs = System.currentTimeMillis()
        saveCheckinTime(context, optimisticTs)
        refreshWidgets(context)

        // 위젯 체크인은 앱(Dart)을 거치지 않으므로, 이전 주기에 예약된 "마감 임박" 알림을
        // 여기서 직접 취소해야 한다. 그러지 않으면 이미 체크인했는데도 알림이 울린다.
        cancelExpirationReminder(context)

        activeJob?.cancel()
        activeJob = scope.launch {
            try {
                val token = readToken(context) ?: run {
                    Log.w(TAG, "토큰 없음 — 체크인 건너뜀")
                    return@launch
                }

                // API 완료 후 서버 확정 시간으로 재갱신
                val ts = callCheckinApi(token)
                if (ts != null) {
                    if (ts != optimisticTs) {
                        saveCheckinTime(context, ts, resetAlertSent = true)
                        refreshWidgets(context)
                    }
                    Log.d(TAG, "위젯 체크인 완료(서버 반영): $ts")
                } else {
                    Log.w(TAG, "위젯 체크인 API 실패 — 낙관적 시간 유지")
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Throwable) {
                Log.e(TAG, "위젯 체크인 오류", e)
            } finally {
                pendingResult.finish()
            }
        }
    }

    /** home_widget이 저장한 HomeWidgetPreferences에서 서버 토큰 읽기 */
    private fun readToken(context: Context): String? {
        return try {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            prefs.getString(TOKEN_KEY, null)
        } catch (e: Exception) {
            Log.e(TAG, "토큰 읽기 실패", e)
            null
        }
    }

    /** POST /api/checkin → checked_at 밀리초 반환, 실패 시 null */
    private fun callCheckinApi(token: String): Long? {
        var conn: HttpURLConnection? = null
        return try {
            conn = (URL(API_URL).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Content-Length", "0")
                doOutput = false
                connectTimeout = 10_000
                readTimeout = 10_000
            }

            val code = conn.responseCode
            Log.d(TAG, "체크인 API 응답 코드: $code")
            if (code == 200) {
                val body = conn.inputStream.bufferedReader().readText()
                val checkedAt = JSONObject(body).optString("checked_at")
                if (checkedAt.isNotEmpty()) parseIso8601(checkedAt) else System.currentTimeMillis()
            } else {
                val errBody = conn.errorStream?.bufferedReader()?.readText() ?: "(없음)"
                Log.w(TAG, "체크인 API 실패 $code: $errBody")
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "체크인 API 오류", e)
            null
        } finally {
            conn?.disconnect()
        }
    }

    /** ISO 8601 문자열 → 밀리초 */
    private fun parseIso8601(s: String): Long {
        return try {
            // "2026-06-17T05:42:00.000Z" → milliseconds
            val fmt = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US)
            fmt.timeZone = java.util.TimeZone.getTimeZone("UTC")
            fmt.parse(s.take(19))?.time ?: System.currentTimeMillis()
        } catch (e: Exception) {
            System.currentTimeMillis()
        }
    }

    /**
     * flutter_local_notifications가 예약해 둔 "마감 임박" 알림(ID 7)을 취소한다.
     * 이 플러그인은 zonedSchedule 시 AlarmManager에 ScheduledNotificationReceiver로 향하는
     * PendingIntent를 등록하므로, 동일한 PendingIntent를 만들어 alarmManager.cancel()로 꺼야
     * 실제로 예약이 취소된다(이미 화면에 떠 있는 경우를 대비해 NotificationManager.cancel도 호출).
     */
    private fun cancelExpirationReminder(context: Context) {
        try {
            val scheduledIntent = Intent(context, ScheduledNotificationReceiver::class.java)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pendingIntent = PendingIntent.getBroadcast(
                context, EXPIRATION_REMINDER_NOTIFICATION_ID, scheduledIntent, flags
            )
            (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pendingIntent)
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(EXPIRATION_REMINDER_NOTIFICATION_ID)
        } catch (e: Exception) {
            Log.e(TAG, "만료 알림 취소 실패", e)
        }
    }

    /** FlutterSharedPreferences 체크인 시간 업데이트 */
    private fun saveCheckinTime(context: Context, ts: Long, resetAlertSent: Boolean = false) {
        val editor = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putLong("flutter.last_check_in", ts)
        if (resetAlertSent) editor.putBoolean("flutter.alert_sent", false)
        editor.apply()
    }

    /** 소형·중형 위젯 즉시 갱신 */
    private fun refreshWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val providers = listOf(
            AnsimWidgetProvider::class.java to true,
            AnsimWidgetMediumProvider::class.java to false
        )
        for ((cls, isSmall) in providers) {
            val ids = manager.getAppWidgetIds(ComponentName(context, cls))
            for (id in ids) {
                AnsimWidgetProvider.updateWidget(context, manager, id, isSmall)
            }
        }
    }
}
