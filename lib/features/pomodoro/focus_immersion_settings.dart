import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum FocusTimerStyle { digital, flip, pixel }

class FocusImmersionSettings {
  const FocusImmersionSettings({
    this.autoEnter = false,
    this.style = FocusTimerStyle.digital,
  });

  final bool autoEnter;
  final FocusTimerStyle style;

  @override
  bool operator ==(Object other) {
    return other is FocusImmersionSettings &&
        other.autoEnter == autoEnter &&
        other.style == style;
  }

  @override
  int get hashCode => Object.hash(autoEnter, style);
}

abstract interface class FocusImmersionSettingsStorage {
  Future<String?> readString(String key);

  Future<bool> writeString(String key, String value);
}

class SharedPreferencesFocusImmersionSettingsStorage
    implements FocusImmersionSettingsStorage {
  @override
  Future<String?> readString(String key) async {
    return (await SharedPreferences.getInstance()).getString(key);
  }

  @override
  Future<bool> writeString(String key, String value) async {
    return (await SharedPreferences.getInstance()).setString(key, value);
  }
}

class FocusImmersionSettingsStore {
  FocusImmersionSettingsStore({required FocusImmersionSettingsStorage storage})
    : _storage = storage;

  static const storageKey = 'todo_focus_immersion_settings_v1';

  final FocusImmersionSettingsStorage _storage;

  Future<FocusImmersionSettings> read() async {
    try {
      final raw = await _storage.readString(storageKey);
      if (raw == null || raw.isEmpty) return const FocusImmersionSettings();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const FocusImmersionSettings();
      }
      final autoEnter = decoded['autoEnter'];
      final styleName = decoded['style'];
      if (autoEnter is! bool || styleName is! String) {
        return const FocusImmersionSettings();
      }
      final style = FocusTimerStyle.values.where(
        (value) => value.name == styleName,
      );
      if (style.isEmpty) return const FocusImmersionSettings();
      return FocusImmersionSettings(autoEnter: autoEnter, style: style.first);
    } catch (_) {
      return const FocusImmersionSettings();
    }
  }

  Future<bool> write(FocusImmersionSettings value) async {
    try {
      return await _storage.writeString(
        storageKey,
        jsonEncode({'autoEnter': value.autoEnter, 'style': value.style.name}),
      );
    } catch (_) {
      return false;
    }
  }
}
