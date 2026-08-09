import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:zh_cloud_todo_flutter/features/pomodoro/focus_immersion_settings.dart';

void main() {
  test(
    'immersion settings default safely when storage is empty or malformed',
    () async {
      final storage = _MemoryStorage();
      final store = FocusImmersionSettingsStore(storage: storage);

      expect(await store.read(), const FocusImmersionSettings());

      storage.values[FocusImmersionSettingsStore.storageKey] = 'not-json';
      expect(await store.read(), const FocusImmersionSettings());

      storage.values[FocusImmersionSettingsStore.storageKey] =
          '{"autoEnter":true,"style":"unknown"}';
      expect(await store.read(), const FocusImmersionSettings());
    },
  );

  test(
    'immersion settings round-trip auto entry and each supported style',
    () async {
      final storage = _MemoryStorage();
      final store = FocusImmersionSettingsStore(storage: storage);

      for (final style in FocusTimerStyle.values) {
        final value = FocusImmersionSettings(autoEnter: true, style: style);
        expect(await store.write(value), isTrue);
        expect(await store.read(), value);
      }
    },
  );

  test(
    'immersion settings read legacy JSON with screen awake disabled',
    () async {
      final storage = _MemoryStorage()
        ..values[FocusImmersionSettingsStore.storageKey] =
            '{"autoEnter":true,"style":"flip"}';
      final store = FocusImmersionSettingsStore(storage: storage);

      final settings = await store.read();

      expect(settings.autoEnter, isTrue);
      expect(settings.style, FocusTimerStyle.flip);
      expect(settings.keepScreenAwake, isFalse);
    },
  );

  test('immersion settings round-trip screen awake preference', () async {
    final storage = _MemoryStorage();
    final store = FocusImmersionSettingsStore(storage: storage);
    const value = FocusImmersionSettings(
      autoEnter: true,
      style: FocusTimerStyle.pixel,
      keepScreenAwake: true,
    );

    expect(await store.write(value), isTrue);
    expect(await store.read(), value);
    expect(
      jsonDecode(storage.values[FocusImmersionSettingsStore.storageKey]!)
          as Map<String, dynamic>,
      containsPair('keepScreenAwake', isTrue),
    );
  });

  test(
    'immersion settings default invalid screen awake fields safely',
    () async {
      final storage = _MemoryStorage();
      final store = FocusImmersionSettingsStore(storage: storage);

      storage.values[FocusImmersionSettingsStore.storageKey] =
          '{"autoEnter":true,"style":"digital","keepScreenAwake":"true"}';

      final settings = await store.read();

      expect(settings.autoEnter, isTrue);
      expect(settings.style, FocusTimerStyle.digital);
      expect(settings.keepScreenAwake, isFalse);
    },
  );

  test('immersion settings report write failure without throwing', () async {
    final storage = _MemoryStorage()..writeSucceeds = false;
    final store = FocusImmersionSettingsStore(storage: storage);

    expect(
      await store.write(
        const FocusImmersionSettings(
          autoEnter: true,
          style: FocusTimerStyle.pixel,
        ),
      ),
      isFalse,
    );
    expect(await store.read(), const FocusImmersionSettings());
  });
}

class _MemoryStorage implements FocusImmersionSettingsStorage {
  final Map<String, String> values = <String, String>{};
  bool writeSucceeds = true;

  @override
  Future<String?> readString(String key) async => values[key];

  @override
  Future<bool> writeString(String key, String value) async {
    if (!writeSucceeds) return false;
    values[key] = value;
    return true;
  }
}
