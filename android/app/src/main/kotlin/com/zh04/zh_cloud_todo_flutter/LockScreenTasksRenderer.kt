package com.zh04.zh_cloud_todo_flutter

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

object LockScreenTasksRenderer {
    private const val CHANNEL_ID = "important_tasks_lock_screen"
    private const val CHANNEL_NAME = "锁屏重要任务"
    private const val CHANNEL_DESCRIPTION = "在锁屏和通知中心持续显示已选择的重要任务"
    private const val NOTIFICATION_ID = 41002

    fun update(
        context: Context,
        tasks: List<NativeLockScreenTask>,
    ): Boolean {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (tasks.isEmpty()) {
            manager.cancel(NOTIFICATION_ID)
            return true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        if (!manager.areNotificationsEnabled()) {
            return false
        }
        createChannel(manager)

        val openApp =
            PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        val countText = "${tasks.size} 项重要任务待处理"
        val privateStyle =
            Notification.InboxStyle()
                .setBigContentTitle("重要任务")
                .setSummaryText(countText)
        tasks.forEach { privateStyle.addLine(it.title) }

        val publicNotification =
            notificationBuilder(context)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("重要任务")
                .setContentText("有 $countText")
                .setCategory(Notification.CATEGORY_REMINDER)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setOngoing(true)
                .setContentIntent(openApp)
                .build()
        val privateNotification =
            notificationBuilder(context)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("重要任务")
                .setContentText(tasks.joinToString(" · ") { it.title })
                .setStyle(privateStyle)
                .setCategory(Notification.CATEGORY_REMINDER)
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setPublicVersion(publicNotification)
                .setOnlyAlertOnce(true)
                .setShowWhen(false)
                .setOngoing(true)
                .setContentIntent(openApp)
                .setNumber(tasks.size)
                .build()
        manager.notify(NOTIFICATION_ID, privateNotification)
        return true
    }

    private fun createChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = CHANNEL_DESCRIPTION
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            },
        )
    }

    @Suppress("DEPRECATION")
    private fun notificationBuilder(context: Context): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
}
