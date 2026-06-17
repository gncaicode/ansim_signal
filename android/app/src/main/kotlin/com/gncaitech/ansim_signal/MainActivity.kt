package com.gncaitech.ansim_signal

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // passive 모드 — Significant Motion 센서 등록
        MotionCheckinManager.register(this)
    }
}
