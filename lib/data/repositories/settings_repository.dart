import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  const SettingsRepository(this._preferences);

  static const _themeModeKey = 'theme_mode';
  static const _customUserAgentKey = 'custom_user_agent';
  static const _currentSourceKey = 'current_source_id';

  final SharedPreferences _preferences;

  ThemeMode themeMode() {
    return switch (_preferences.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return _preferences.setString(_themeModeKey, mode.name);
  }

  String customUserAgent() {
    return _preferences.getString(_customUserAgentKey)?.trim() ?? '';
  }

  Future<void> setCustomUserAgent(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return _preferences.remove(_customUserAgentKey);
    }
    return _preferences.setString(_customUserAgentKey, normalized);
  }

  String? currentSourceId() {
    final value = _preferences.getString(_currentSourceKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> setCurrentSourceId(String sourceId) {
    final normalized = sourceId.trim();
    if (normalized.isEmpty) {
      return _preferences.remove(_currentSourceKey);
    }
    return _preferences.setString(_currentSourceKey, normalized);
  }
}
