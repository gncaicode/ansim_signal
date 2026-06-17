package com.gncaitech.ansim_signal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import dev.fluttercommunity.workmanager.BackgroundWorker

/**
 * 잠금 해제(ACTION_USER_PRESENT) 수신자.
 * passive 모드이고 마감이 지난 경우 flutter_workmanager BackgroundWorker를 실행.
 * BackgroundWorker가 Flutter 엔진을 띄워 Dart callbackDispatcher를 호출함.
 */
class UserPresentReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_USER_PRESENT) return

        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )

        val mode = prefs.getString("flutter.checkin_mode", "manual") ?: "manual"
        if (mode != "passive") return

        val lastMs = prefs.getLong("flutter.last_check_in", 0L)
        val intervalHours = prefs.getLong("flutter.interval_hours", 24L)
        val deadline = lastMs + intervalHours * 3_600_000L
        if (System.currentTimeMillis() < deadline) return

        WorkManager.getInstance(context)
            .enqueueUniqueWork(
                "ansim-screen-unlock",
                ExistingWorkPolicy.KEEP,
                OneTimeWorkRequestBuilder<BackgroundWorker>()
                    .setInputData(
                        workDataOf(BackgroundWorker.DART_TASK_KEY to "ansim-passive-checkin")
                    )
                    .build()
            )
    }
}
