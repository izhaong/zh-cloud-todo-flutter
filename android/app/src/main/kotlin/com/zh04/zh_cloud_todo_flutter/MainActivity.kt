package com.zh04.zh_cloud_todo_flutter

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingInitialLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingInitialLink = NativeIntentContract.acceptedIncomingLink(intent?.dataString)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        pendingInitialLink =
            NativeIntentContract.acceptedIncomingLink(intent.dataString) ?: pendingInitialLink
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialLink" -> {
                    result.success(pendingInitialLink)
                    pendingInitialLink = null
                }

                "share" -> {
                    val request = NativeIntentContract.shareRequest(call.arguments)
                    if (request == null) {
                        result.error("invalid_arguments", "分享文本不能为空", null)
                    } else {
                        share(request, result)
                    }
                }

                "setStickyNote" -> {
                    val content = NativeIntentContract.stickyNoteContent(call.arguments)
                    if (content == null) {
                        result.error("invalid_arguments", "便签内容不能为空", null)
                    } else {
                        createSystemNote(content, result)
                    }
                }

                "pushLockScreenTasks",
                "widgetTodaySnapshot",
                -> result.notImplemented()

                else -> result.notImplemented()
            }
        }
    }

    private fun share(
        request: NativeShareRequest,
        result: MethodChannel.Result,
    ) {
        val sendIntent =
            Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, request.text)
                request.subject?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
            }
        try {
            startActivity(Intent.createChooser(sendIntent, request.subject))
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            result.error("share_unavailable", "没有可用的系统分享应用", null)
        }
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
    }
}
