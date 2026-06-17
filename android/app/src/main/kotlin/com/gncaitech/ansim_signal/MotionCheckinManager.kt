package com.gncaitech.ansim_signal

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.hardware.TriggerEvent
import android.hardware.TriggerEventListener
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import dev.fluttercommunity.workmanager.BackgroundWorker

/**
 * Significant Motion Sensor 관리자.
 * - 하드웨어 레벨 움직임 감지 (배터리 소모 최소)
 * - one-shot 방식이므로 감지 후 재등록 필요
 * - 반드시 Looper가 있는 스레드(메인 스레드)에서 등록해야 이벤트 수신 가능
 */
object MotionCheckinManager {

    private const val TAG = "MotionCheckin"

    private var sensorManager: SensorManager? = null
    private var triggerListener: TriggerEventListener? = null

    fun register(context: Context) {
        if (Looper.myLooper() == null) {
            Handler(Looper.getMainLooper()).post { register(context) }
            return
        }

        val appContext = context.applicationContext
        val sm = appContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val sensor = sm.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION)

        if (sensor == null) {
            Log.w(TAG, "TYPE_SIGNIFICANT_MOTION sensor not available on this device")
            return
        }

        sensorManager = sm
        triggerListener?.let { sm.cancelTriggerSensor(it, sensor) }

        val prefs = appContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )

        triggerListener = object : TriggerEventListener() {
            override fun onTrigger(event: TriggerEvent) {
                val mode = prefs.getString("flutter.checkin_mode", "manual") ?: "manual"
                val lastMs = prefs.getLong("flutter.last_check_in", 0L)
                val intervalHours = prefs.getLong("flutter.interval_hours", 24L)
                val deadline = lastMs + intervalHours * 3_600_000L

                if (mode == "passive" && System.currentTimeMillis() >= deadline) {
                    WorkManager.getInstance(appContext)
                        .enqueueUniqueWork(
                            "ansim-motion-checkin",
                            ExistingWorkPolicy.KEEP,
                            OneTimeWorkRequestBuilder<BackgroundWorker>()
                                .setInputData(
                                    workDataOf(BackgroundWorker.DART_TASK_KEY to "ansim-passive-checkin")
                                )
                                .build()
                        )
                }
                // one-shot 이므로 재등록
                register(appContext)
            }
        }

        sm.requestTriggerSensor(triggerListener!!, sensor)
    }

    fun unregister() {
        val sm = sensorManager ?: return
        val sensor = sm.getDefaultSensor(Sensor.TYPE_SIGNIFICANT_MOTION) ?: return
        triggerListener?.let { sm.cancelTriggerSensor(it, sensor) }
        triggerListener = null
    }
}
