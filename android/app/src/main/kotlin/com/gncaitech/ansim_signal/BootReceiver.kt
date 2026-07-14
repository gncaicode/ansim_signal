package com.gncaitech.ansim_signal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 기기 재부팅/앱 업데이트 후 Significant Motion 센서 재등록.
 * MotionCheckinManager는 프로세스가 살아있는 동안에만 트리거가 유지되므로,
 * 재부팅으로 죽은 트리거를 다시 등록해준다.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) return

        MotionCheckinManager.register(context.applicationContext)
    }
}
