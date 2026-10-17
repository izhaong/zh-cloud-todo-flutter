# 161 台账

## T1 取证

- [x] 客户端 `id: item.id` 直接当 OS 通知 id（`reminder_notification_poller.dart:183/191`）。
- [x] `body` 写死「到期提醒」⇒ 提及若走这条链会被写成到期提醒。
- [x] opencode（#358）：「唯一真正必须统一的：身份/去重键……否则两条流的通知 id 会在通知中心相撞」。

## T2 改动

- [x] `todo_notification_id.dart`（两类两个区间 + 取模防抛错）。
- [x] poller 走 `reminderOsNotificationId`。
      复跑：`grep -n "id: reminderOsNotificationId" lib/core/notification/reminder_notification_poller.dart`
      ⇒ 恰 **2** 处（`schedule` 与 `show` 各一）。
- [x] 客户端 `TodoNotificationApi`（独立端点 + `TodoNotificationItem`，`isMention` 分流标记）。

## T3 判据与探针

- [x] 5 条判据（跨类型不相等 / 同类型不塌缩 / 同 id 稳定 / 异常 id 不抛错 / 两套类型）。
- [x] **反向探针**：两类同区间 ⇒ 「跨类型永不相等」转红。
- [x] 既有 2 条钉裸 id 的 poller 用例改为按命名空间断言（它们钉的正是这次的病灶）。
      复跑：`grep -n "reminderOsNotificationId(" test/reminder_notification_poller_test.dart | wc -l`
      ⇒ **2** 处断言（第一次实测写的是 3 —— 没数对就写上，被复跑抓出来订正）。
- [x] 全量 `+2125 ~26`，0 失败。

## 过程教训

1. **id 撞车这类 bug 在单端测试里根本测不出来** —— 要等两个功能都上线、用户真的同时收到
   两条通知才会显形。opencode 在设计评审阶段就把"唯一会真痛的重复"点了出来。
2. **"宁可塌缩，不可抛错"**：异常 id 取模后两条通知共用一个 OS id 是可接受的退化
   （用户少看到一条）；抛错会让**整轮 poll 中断**（所有提醒都不响），那才是不可接受的。
   两者的取舍要写进判据（`returnsNormally`）。

## 最终门禁

| 门 | 读数 |
| --- | --- |
| 该文件 | `+5 All tests passed!` |
| 反向探针 | 转红 |
| 既有 poller 用例（按新命名空间） | `+10 All tests passed!` |
| `flutter analyze` / `dart format` | 0 issue / rc=0 |
| 全量（exclude golden/performance） | `+2125 ~26`，**0 失败** |
