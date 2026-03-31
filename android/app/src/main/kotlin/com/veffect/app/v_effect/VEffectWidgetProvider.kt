package com.veffect.app.v_effect

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class VEffectWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.veffect_widget_layout)

            // データの取得
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val streak = prefs.getInt("streak", 0)
            val postedToday = prefs.getBoolean("postedToday", false)
            val isAllTasksCompleted = prefs.getBoolean("isAllTasksCompleted", false)

            // UIの更新
            views.setTextViewText(R.id.widget_streak_count, streak.toString())
            
            val statusText = when {
                isAllTasksCompleted -> "Mission Complete!"
                postedToday -> "Keep going!"
                else -> "Today's Victory?"
            }
            views.setTextViewText(R.id.widget_status_text, statusText)

            // アプリアイコンとテキストに背景色などを設定してV-EFFECTらしく
            // (XML側で定義済み)

            // タップでアプリを起動し、カメラ画面へ（HomeWidgetの標準機能を利用）
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("veffect://camera")
            )
            views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
