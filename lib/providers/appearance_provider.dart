import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppearanceState {
  final ThemeMode mode;
  final bool amoled;
  final bool useCustomAccent;
  final Color customAccent;
  final String fontFamily;

  const AppearanceState({
    required this.mode,
    required this.amoled,
    required this.useCustomAccent,
    required this.customAccent,
    required this.fontFamily,
  });

  AppearanceState copyWith({
    ThemeMode? mode,
    bool? amoled,
    bool? useCustomAccent,
    Color? customAccent,
    String? fontFamily,
  }) {
    return AppearanceState(
      mode: mode ?? this.mode,
      amoled: amoled ?? this.amoled,
      useCustomAccent: useCustomAccent ?? this.useCustomAccent,
      customAccent: customAccent ?? this.customAccent,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

class AppearanceNotifier extends Notifier<AppearanceState> {
  static const _modeKey = 'appearance_mode';
  static const _amoledKey = 'appearance_amoled';
  static const _customAccentKey = 'appearance_custom_accent';
  static const _accentKey = 'appearance_accent';
  static const _fontKey = 'appearance_font';

  @override
  AppearanceState build() {
    _load();
    return const AppearanceState(
      mode: ThemeMode.dark,
      amoled: false,
      useCustomAccent: false,
      customAccent: Color(0xFF6750A4),
      fontFamily: 'Inter',
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;

    final mode = switch (prefs.getString(_modeKey)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    final accent = Color(prefs.getInt(_accentKey) ?? 0xFF6750A4);

    state = state.copyWith(
      mode: mode,
      amoled: prefs.getBool(_amoledKey) ?? false,
      useCustomAccent: prefs.getBool(_customAccentKey) ?? false,
      customAccent: accent,
      fontFamily: prefs.getString(_fontKey) ?? 'Inter',
    );
  }

  Future<void> setMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      ThemeMode.dark => 'dark',
    });
  }

  Future<void> setAmoled(bool value) async {
    state = state.copyWith(amoled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_amoledKey, value);
  }

  Future<void> setCustomAccentEnabled(bool value) async {
    state = state.copyWith(useCustomAccent: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_customAccentKey, value);
  }

  Future<void> setAccent(Color color) async {
    state = state.copyWith(customAccent: color, useCustomAccent: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentKey, color.toARGB32());
    await prefs.setBool(_customAccentKey, true);
  }

  Future<void> setFont(String fontFamily) async {
    state = state.copyWith(fontFamily: fontFamily);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, fontFamily);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, AppearanceState>(
      AppearanceNotifier.new,
    );
