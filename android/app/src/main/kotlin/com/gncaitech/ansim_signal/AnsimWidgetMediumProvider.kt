package com.gncaitech.ansim_signal

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/**
 * 안심시그널 중형 홈 위젯 (4×2).
 * AnsimWidgetProvider의 공통 로직 재사용.
 */
class AnsimWidgetMediumProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            AnsimWidgetProvider.updateWidget(context, appWidgetManager, id, isSmall = false)
        }
    }
}
