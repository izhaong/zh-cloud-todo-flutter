package com.zh04.zh_cloud_todo_flutter

import java.net.URI
import java.net.URISyntaxException

data class NativeShareRequest(
    val text: String,
    val subject: String?,
)

object NativeIntentContract {
    const val SYSTEM_NOTE_ACTION = "android.intent.action.CREATE_NOTE"

    private const val URL_SCHEME = "zhcloudtodo"
    private const val TASK_HOST = "task"
    private const val TASK_ADD_PATH = "/add"
    private const val SYSTEM_NOTE_MIN_API = 34

    fun acceptedIncomingLink(rawLink: String?): String? {
        val uri =
            try {
                rawLink?.let(::URI)
            } catch (_: URISyntaxException) {
                null
            } ?: return null
        if (!uri.scheme.equals(URL_SCHEME, ignoreCase = true)) return null
        if (!uri.host.equals(TASK_HOST, ignoreCase = true)) return null
        if (uri.path != TASK_ADD_PATH) return null
        return rawLink
    }

    fun shareRequest(arguments: Any?): NativeShareRequest? {
        val map = arguments as? Map<*, *> ?: return null
        val text = (map["text"] as? String)?.trim().orEmpty()
        if (text.isEmpty()) return null
        val subject = (map["subject"] as? String)?.trim()?.takeIf(String::isNotEmpty)
        return NativeShareRequest(text = text, subject = subject)
    }

    fun stickyNoteContent(arguments: Any?): String? {
        val map = arguments as? Map<*, *> ?: return null
        return (map["content"] as? String)?.trim()?.takeIf(String::isNotEmpty)
    }

    fun supportsSystemNote(apiLevel: Int): Boolean = apiLevel >= SYSTEM_NOTE_MIN_API
}
