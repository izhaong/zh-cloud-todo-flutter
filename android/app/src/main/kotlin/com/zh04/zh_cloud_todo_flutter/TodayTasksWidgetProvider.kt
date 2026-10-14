package com.zh04.zh_cloud_todo_flutter

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.app.PendingIntent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class TodayTasksWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val tasks = titlesFrom(widgetData.getString(TASKS_KEY, null))
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(
                appWidgetId,
                remoteViews(context, tasks),
            )
        }
    }

    companion object {
        private const val TASKS_KEY = "tasks"
        private val taskRowIds =
            intArrayOf(
                R.id.widget_task_1,
                R.id.widget_task_2,
                R.id.widget_task_3,
                R.id.widget_task_4,
                R.id.widget_task_5,
            )

        private fun titlesFrom(raw: String?): List<String> {
            if (raw.isNullOrBlank()) return emptyList()
            return try {
                val values = JSONArray(raw)
                buildList {
                    for (index in 0 until values.length()) {
                        val title = values.optString(index).trim()
                        if (title.isNotEmpty()) add(title)
                    }
                }
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun remoteViews(
            context: Context,
            tasks: List<String>,
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.today_tasks_widget)
            views.setViewVisibility(
                R.id.widget_empty,
                if (tasks.isEmpty()) View.VISIBLE else View.GONE,
            )
            taskRowIds.forEachIndexed { index, viewId ->
                val task = tasks.getOrNull(index)
                views.setViewVisibility(
                    viewId,
                    if (task == null) View.GONE else View.VISIBLE,
                )
                if (task != null) views.setTextViewText(viewId, "• $task")
            }
            val openApp =
                PendingIntent.getActivity(
                    context,
                    0,
                    Intent(context, MainActivity::class.java),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            views.setOnClickPendingIntent(R.id.widget_root, openApp)
            return views
        }
    }
}
