package com.zh04.zh_cloud_todo_flutter

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingInitialLink: String? = null
    private val warmLinks = NativeLinkEvents()

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingInitialLink = NativeIntentContract.acceptedIncomingLink(intent?.dataString)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        warmLinks.publish(intent.dataString)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "supportsLinkEvents" -> result.success(true)

                "getInitialLink" -> {
                    result.success(pendingInitialLink)
                    pendingInitialLink = null
                }

                "setStickyNote" -> {
                    val content = NativeIntentContract.stickyNoteContent(call.arguments)
                    if (content == null) {
                        result.error("invalid_arguments", "便签内容不能为空", null)
                    } else {
                        createSystemNote(content, result)
                    }
                }

                "pushLockScreenTasks" -> {
                    val tasks = NativeIntentContract.lockScreenTasks(call.arguments)
                    if (tasks == null) {
                        result.error("invalid_arguments", "锁屏任务快照无效", null)
                    } else {
                        result.success(LockScreenTasksRenderer.update(this, tasks))
                    }
                }

                else -> result.notImplemented()
            }
        }
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_LINK_EVENTS_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink,
                ) {
                    warmLinks.attach(events::success)
                }

                override fun onCancel(arguments: Any?) {
                    warmLinks.detach()
                }
            },
        )
    }

    private fun createSystemNote(
        content: String,
        result: MethodChannel.Result,
    ) {
        if (!NativeIntentContract.supportsSystemNote(Build.VERSION.SDK_INT)) {
            result.notImplemented()
            return
        }
        val noteIntent =
            Intent(NativeIntentContract.SYSTEM_NOTE_ACTION).apply {
                putExtra(Intent.EXTRA_TEXT, content)
            }
        if (noteIntent.resolveActivity(packageManager) == null) {
            result.notImplemented()
            return
        }
        try {
            startActivity(noteIntent)
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            result.notImplemented()
        }
    }

    companion object {
        private const val NATIVE_CHANNEL = "zh_cloud_todo/native"
        private const val NATIVE_LINK_EVENTS_CHANNEL = "zh_cloud_todo/native_links"
    }
}
