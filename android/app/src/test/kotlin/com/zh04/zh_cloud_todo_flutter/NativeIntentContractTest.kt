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
    fun `keep screen awake accepts only a boolean enabled map`() {
        assertEquals(
            true,
            NativeIntentContract.keepScreenAwakeEnabled(mapOf("enabled" to true)),
        )
        assertEquals(
            false,
            NativeIntentContract.keepScreenAwakeEnabled(mapOf("enabled" to false)),
        )
        assertNull(NativeIntentContract.keepScreenAwakeEnabled(emptyMap<String, Any?>()))
        assertNull(NativeIntentContract.keepScreenAwakeEnabled(null))
        assertNull(NativeIntentContract.keepScreenAwakeEnabled("true"))
        assertNull(
            NativeIntentContract.keepScreenAwakeEnabled(mapOf("enabled" to "true")),
        )
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

    @Test
    fun `today widget snapshot trims titles rejects invalid entries and limits rows`() {
        assertEquals(
            listOf(
                TodayWidgetTask("第一项"),
                TodayWidgetTask("第二项"),
                TodayWidgetTask("第三项"),
                TodayWidgetTask("第四项"),
                TodayWidgetTask("第五项"),
            ),
            NativeIntentContract.todayWidgetTasks(
                mapOf(
                    "tasks" to
                        listOf(
                            mapOf("title" to " 第一项 "),
                            mapOf("title" to "第二项"),
                            mapOf("title" to "第三项"),
                            mapOf("title" to "第四项"),
                            mapOf("title" to "第五项"),
                            mapOf("title" to "第六项"),
                        ),
                ),
            ),
        )
        assertEquals(
            emptyList(),
            NativeIntentContract.todayWidgetTasks(mapOf("tasks" to emptyList<Any>())),
        )
        assertNull(
            NativeIntentContract.todayWidgetTasks(
                mapOf("tasks" to listOf(mapOf("title" to "  "))),
            ),
        )
        assertNull(NativeIntentContract.todayWidgetTasks(null))
    }

    @Test
    fun `lock screen snapshot requires real positive ids and bounded non blank titles`() {
        assertEquals(
            listOf(
                NativeLockScreenTask(serverId = 101, title = "第一项"),
                NativeLockScreenTask(serverId = 102, title = "第二项"),
                NativeLockScreenTask(serverId = 103, title = "第三项"),
                NativeLockScreenTask(serverId = 104, title = "第四项"),
                NativeLockScreenTask(serverId = 105, title = "第五项"),
            ),
            NativeIntentContract.lockScreenTasks(
                mapOf(
                    "tasks" to
                        listOf(
                            mapOf("id" to 101, "title" to " 第一项 "),
                            mapOf("id" to 102L, "title" to "第二项"),
                            mapOf("id" to 103, "title" to "第三项"),
                            mapOf("id" to 104, "title" to "第四项"),
                            mapOf("id" to 105, "title" to "第五项"),
                            mapOf("id" to 106, "title" to "第六项"),
                        ),
                ),
            ),
        )
        assertEquals(
            NativeLockScreenTask(serverId = 201, title = "长".repeat(80)),
            NativeIntentContract
                .lockScreenTasks(
                    mapOf(
                        "tasks" to
                            listOf(
                                mapOf("id" to 201, "title" to "长".repeat(81)),
                            ),
                    ),
                )!!
                .single(),
        )
        assertEquals(
            NativeLockScreenTask(
                serverId = 202,
                title = "${"长".repeat(79)}😀",
            ),
            NativeIntentContract
                .lockScreenTasks(
                    mapOf(
                        "tasks" to
                            listOf(
                                mapOf(
                                    "id" to 202,
                                    "title" to "${"长".repeat(79)}😀额外",
                                ),
                            ),
                    ),
                )!!
                .single(),
        )
        assertEquals(
            emptyList(),
            NativeIntentContract.lockScreenTasks(mapOf("tasks" to emptyList<Any>())),
        )
        assertNull(
            NativeIntentContract.lockScreenTasks(
                mapOf("tasks" to listOf(mapOf("id" to 0, "title" to "无效 ID"))),
            ),
        )
        assertNull(
            NativeIntentContract.lockScreenTasks(
                mapOf("tasks" to listOf(mapOf("id" to 1.5, "title" to "非整数 ID"))),
            ),
        )
        assertNull(
            NativeIntentContract.lockScreenTasks(
                mapOf("tasks" to listOf(mapOf("id" to 202, "title" to "  "))),
            ),
        )
        assertNull(NativeIntentContract.lockScreenTasks(null))
    }
}
