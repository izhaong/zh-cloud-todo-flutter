// 纯单元测试逻辑：命中 CollaborationApi/CalendarSubscriptionApi 的 response parser，
// 不连网；只验证模型构造。
import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/core/api/todo_api.dart';

void main() {
  group('ListCollaborationApi / ListMember 模型构造', () {
    test('ListMember 基本字段 + isOwner 行为', () {
      const owner = ListMember(
        userId: 42,
        role: 'owner',
        mobile: '188****0042',
        displayName: 'Test',
      );
      expect(owner.userId, 42);
      expect(owner.isOwner, isTrue);
      expect(owner.mobile, contains('0042'));

      const member = ListMember(userId: 7, role: 'member');
      expect(member.isOwner, isFalse);
      expect(member.displayName, isNull);
    });
  });

  group('TaskComment 构造', () {
    test('字段透传（不含 parseTime 重构）', () {
      final c = TaskComment(
        id: 1,
        taskId: 100,
        content: 'hello',
        userId: 5,
        createdAt: DateTime(2026, 7, 7),
      );
      expect(c.id, 1);
      expect(c.taskId, 100);
      expect(c.content, 'hello');
      expect(c.userId, 5);
      expect(c.createdAt, DateTime(2026, 7, 7));
    });
  });

  group('CalSubscription 构造', () {
    test('字段透传', () {
      const s = CalSubscription(
        id: 9,
        url: 'https://x.co/cal.ics',
        name: 'test',
        enabled: false,
      );
      expect(s.id, 9);
      expect(s.url, contains('https://'));
      expect(s.enabled, isFalse);
      expect(s.lastSyncAt, isNull);
    });
  });
}
