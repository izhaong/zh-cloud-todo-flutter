package com.zh04.zh_cloud_todo_flutter

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class NativeIntentContractTest {
    @Test
    fun `only accepts the task add deep link contract`() {
        assertEquals(
            "zhcloudtodo://task/add?title=%E6%8F%90%E4%BA%A4%E6%8A%A5%E5%91%8A",
            NativeIntentContract.acceptedIncomingLink(
                "zhcloudtodo://task/add?title=%E6%8F%90%E4%BA%A4%E6%8A%A5%E5%91%8A",
            ),
        )
        assertNull(NativeIntentContract.acceptedIncomingLink("https://todo.test/task/add"))
        assertNull(NativeIntentContract.acceptedIncomingLink("zhcloudtodo://task/delete?id=1"))
        assertNull(NativeIntentContract.acceptedIncomingLink("not a uri"))
    }

    @Test
    fun `share request requires non blank text and keeps an optional subject`() {
        assertEquals(
            NativeShareRequest(text = "今日任务", subject = "ZH-CLOUD Todo"),
            NativeIntentContract.shareRequest(
                mapOf("text" to " 今日任务 ", "subject" to " ZH-CLOUD Todo "),
            ),
        )
        assertEquals(
            NativeShareRequest(text = "今日任务", subject = null),
            NativeIntentContract.shareRequest(mapOf("text" to "今日任务")),
        )
        assertNull(NativeIntentContract.shareRequest(mapOf("text" to "   ")))
        assertNull(NativeIntentContract.shareRequest(null))
    }

    @Test
    fun `sticky note rejects blank content and trims valid content`() {
        assertEquals(
            "今日重点",
            NativeIntentContract.stickyNoteContent(mapOf("content" to " 今日重点 ")),
        )
        assertNull(NativeIntentContract.stickyNoteContent(mapOf("content" to "\n  ")))
        assertNull(NativeIntentContract.stickyNoteContent(emptyMap<String, Any?>()))
    }

    @Test
    fun `system note is only offered on Android 14 or newer`() {
        assertEquals(false, NativeIntentContract.supportsSystemNote(apiLevel = 33))
        assertEquals(true, NativeIntentContract.supportsSystemNote(apiLevel = 34))
    }

    @Test
    fun `warm links keep only the latest accepted event until Dart listens`() {
        val events = NativeLinkEvents()
        val received = mutableListOf<String>()

        assertFalse(events.publish("https://todo.test/task/add"))
        assertTrue(events.publish("zhcloudtodo://task/add?title=first"))
        assertTrue(events.publish("zhcloudtodo://task/add?title=latest"))

        events.attach(received::add)
        assertEquals(listOf("zhcloudtodo://task/add?title=latest"), received)

        assertTrue(events.publish("zhcloudtodo://task/add?title=live"))
        assertEquals(
            listOf(
                "zhcloudtodo://task/add?title=latest",
                "zhcloudtodo://task/add?title=live",
            ),
            received,
        )

        events.detach()
        assertTrue(events.publish("zhcloudtodo://task/add?title=resume"))
        events.attach(received::add)
        assertEquals("zhcloudtodo://task/add?title=resume", received.last())
    }
}
