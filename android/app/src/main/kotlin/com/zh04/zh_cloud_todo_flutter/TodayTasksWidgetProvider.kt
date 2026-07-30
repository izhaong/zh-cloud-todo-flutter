package com.zh04.zh_cloud_todo_flutter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.edit
import org.json.JSONArray

object TodayTasksWidgetStore {
    private const val PREFERENCES_NAME = "today_tasks_widget"
    private const val TASKS_KEY = "tasks"

    fun save(
        context: Context,
        tasks: List<TodayWidgetTask>,
    ) {
        val encoded = JSONArray()
        tasks.forEach { encoded.put(it.title) }
        context
            .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit {
                putString(TASKS_KEY, encoded.toString())
            }
    }

    fun load(context: Context): List<TodayWidgetTask> {
        val encoded =
            context
                .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .getString(TASKS_KEY, null)
                ?: return emptyList()
        return try {
            val values = JSONArray(encoded)
            buildList {
                for (index in 0 until values.length()) {
                    val title = values.optString(index).trim()
                    if (title.isNotEmpty()) add(TodayWidgetTask(title))
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}

class TodayTasksWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val tasks = TodayTasksWidgetStore.load(context)
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(
                appWidgetId,
                remoteViews(context, tasks),
            )
        }
    }

    companion object {
        private val taskRowIds =
            intArrayOf(
                R.id.widget_task_1,
                R.id.widget_task_2,
                R.id.widget_task_3,
                R.id.widget_task_4,
                R.id.widget_task_5,
            )

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, TodayTasksWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isNotEmpty()) {
                TodayTasksWidgetProvider().onUpdate(context, manager, ids)
            }
        }

        private fun remoteViews(
            context: Context,
            tasks: List<TodayWidgetTask>,
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
                if (task != null) views.setTextViewText(viewId, "• ${task.title}")
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
