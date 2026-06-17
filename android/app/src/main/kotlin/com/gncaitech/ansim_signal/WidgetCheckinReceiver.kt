package com.gncaitech.ansim_signal

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
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
        private const val TOKEN_KEY = "server_token"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()

        // 낙관적 업데이트: 버튼 탭 즉시 현재 시간으로 위젯 갱신
        val optimisticTs = System.currentTimeMillis()
        saveCheckinTime(context, optimisticTs)
        refreshWidgets(context)

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val token = readToken(context) ?: run {
                    Log.w(TAG, "토큰 없음 — 체크인 건너뜀")
                    return@launch
                }

                // API 완료 후 서버 확정 시간으로 재갱신
                val ts = callCheckinApi(token)
                if (ts != null && ts != optimisticTs) {
                    saveCheckinTime(context, ts)
                    refreshWidgets(context)
                    Log.d(TAG, "위젯 체크인 완료(서버 시간 반영): $ts")
                } else {
                    Log.d(TAG, "위젯 체크인 완료(낙관적 시간 유지)")
                }
            } catch (e: Exception) {
                Log.e(TAG, "위젯 체크인 오류", e)
            } finally {
                pendingResult.finish()
            }
        }
    }

    /** FlutterSecureStorage(EncryptedSharedPreferences)에서 서버 토큰 읽기 */
    private fun readToken(context: Context): String? {
        return try {
            val masterKey = MasterKey.Builder(context.applicationContext)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            val prefs = EncryptedSharedPreferences.create(
                context.applicationContext,
                "FlutterSecureStorage",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
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
                connectTimeout = 10_000
                readTimeout = 10_000
            }
            conn.connect()

            if (conn.responseCode == 200) {
                val body = conn.inputStream.bufferedReader().readText()
                val checkedAt = JSONObject(body).optString("checked_at")
                if (checkedAt.isNotEmpty()) parseIso8601(checkedAt) else System.currentTimeMillis()
            } else null
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

    /** FlutterSharedPreferences 체크인 시간 업데이트 */
    private fun saveCheckinTime(context: Context, ts: Long) {
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit()
            .putLong("flutter.last_check_in", ts)
            .putBoolean("flutter.alert_sent", false)
            .apply()
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
