import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kPrefResumeNotification    = 'pref_resume_notification';
const kPrefUseHookAppIcon        = 'pref_use_hook_app_icon';
const kPrefRoundIcon             = 'pref_round_icon';
const kPrefMarqueeFeature        = 'pref_marquee_feature';
const kPrefMarqueeSpeed          = 'pref_marquee_speed';
const kPrefWrapLongText          = 'pref_wrap_long_text';
const kPrefThemeMode             = 'pref_theme_mode';
const kPrefLocale                = 'pref_locale';
const kPrefCheckUpdateOnLaunch   = 'pref_check_update_on_launch';
/// 超级岛边框高亮颜色，十六进制字符串如 "#E040FB"，空字符串表示使用系统默认。
const kPrefIslandHighlightColor  = 'pref_island_highlight_color';
/// 焦点通知背景颜色，十六进制字符串如 "#1A000000"（含 alpha），空字符串表示使用系统默认。
const kPrefFocusNotifBgColor     = 'pref_focus_notif_bg_color';
/// 超级岛背景填充色，十六进制字符串如 "#CC000000"（含 alpha），空字符串表示使用系统默认。
const kPrefIslandBgColor         = 'pref_island_bg_color';
class SettingsController extends ChangeNotifier {
  static final SettingsController instance = SettingsController._();

  SettingsController._() {
    _load();
  }

  bool resumeNotification = true;
  bool useHookAppIcon = true;
  bool roundIcon = true;
  bool marqueeFeature = false;
  int marqueeSpeed = 100;
  bool wrapLongText = false;
  bool checkUpdateOnLaunch = true;
  ThemeMode themeMode = ThemeMode.system;
  Locale? locale; // null = follow system
  /// 超级岛边框高亮颜色；null / 空字符串表示使用系统默认。
  String? islandHighlightColor;
  /// 焦点通知（FakeStatusView）背景颜色；null / 空字符串表示使用系统默认。
  String? focusNotifBgColor;
  /// 超级岛背景填充色；null / 空字符串表示使用系统默认（透明）。
  String? islandBgColor;
  bool loading = true;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    resumeNotification    = prefs.getBool(kPrefResumeNotification) ?? true;
    useHookAppIcon        = prefs.getBool(kPrefUseHookAppIcon) ?? true;
    roundIcon             = prefs.getBool(kPrefRoundIcon) ?? true;
    marqueeFeature        = prefs.getBool(kPrefMarqueeFeature) ?? false;
    marqueeSpeed          = (prefs.getInt(kPrefMarqueeSpeed) ?? 100).clamp(20, 500);
    wrapLongText          = prefs.getBool(kPrefWrapLongText) ?? false;
    checkUpdateOnLaunch   = prefs.getBool(kPrefCheckUpdateOnLaunch) ?? true;
    // 颜色偏好：存储为十六进制字符串（如 "#E040FB"），空字符串视为未设置
    final rawIsland = prefs.getString(kPrefIslandHighlightColor) ?? '';
    islandHighlightColor  = rawIsland.isEmpty ? null : rawIsland;
    final rawFocus = prefs.getString(kPrefFocusNotifBgColor) ?? '';
    focusNotifBgColor     = rawFocus.isEmpty ? null : rawFocus;
    final rawIslandBg = prefs.getString(kPrefIslandBgColor) ?? '';
    islandBgColor         = rawIslandBg.isEmpty ? null : rawIslandBg;
    themeMode = switch (prefs.getString(kPrefThemeMode)) {
      'light'  => ThemeMode.light,
      'dark'   => ThemeMode.dark,
      _        => ThemeMode.system,
    };
    final localeStr = prefs.getString(kPrefLocale);
    locale = localeStr != null ? Locale(localeStr) : null;
    loading = false;
    notifyListeners();
  }

  Future<void> setResumeNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefResumeNotification, value);
    resumeNotification = value;
    notifyListeners();
  }

  Future<void> setUseHookAppIcon(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefUseHookAppIcon, value);
    useHookAppIcon = value;
    notifyListeners();
  }

  Future<void> setRoundIcon(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefRoundIcon, value);
    roundIcon = value;
    notifyListeners();
  }

  Future<void> setMarqueeFeature(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefMarqueeFeature, value);
    marqueeFeature = value;
    notifyListeners();
  }

  Future<void> setMarqueeSpeed(int value) async {
    final clamped = value.clamp(20, 500);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefMarqueeSpeed, clamped);
    marqueeSpeed = clamped;
    notifyListeners();
  }

  Future<void> setWrapLongText(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefWrapLongText, value);
    wrapLongText = value;
    notifyListeners();
  }

  /// 设置超级岛边框高亮颜色。[value] 为十六进制字符串（如 "#E040FB"），
  /// 传 null 或空字符串可恢复系统默认。
  Future<void> setIslandHighlightColor(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = (value == null || value.isEmpty) ? '' : value;
    await prefs.setString(kPrefIslandHighlightColor, normalized);
    islandHighlightColor = normalized.isEmpty ? null : normalized;
    notifyListeners();
  }

  /// 设置焦点通知背景颜色。[value] 为十六进制字符串（如 "#CC000000"，含 alpha），
  /// 传 null 或空字符串可恢复系统默认。
  Future<void> setFocusNotifBgColor(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = (value == null || value.isEmpty) ? '' : value;
    await prefs.setString(kPrefFocusNotifBgColor, normalized);
    focusNotifBgColor = normalized.isEmpty ? null : normalized;
    notifyListeners();
  }

  /// 设置超级岛背景填充色。[value] 为十六进制字符串（如 "#CC000000"，含 alpha），
  /// 传 null 或空字符串可恢复系统默认（透明）。
  Future<void> setIslandBgColor(String? value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = (value == null || value.isEmpty) ? '' : value;
    await prefs.setString(kPrefIslandBgColor, normalized);
    islandBgColor = normalized.isEmpty ? null : normalized;
    notifyListeners();
  }

  Future<void> setCheckUpdateOnLaunch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefCheckUpdateOnLaunch, value);
    checkUpdateOnLaunch = value;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final str = switch (mode) {
      ThemeMode.light  => 'light',
      ThemeMode.dark   => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(kPrefThemeMode, str);
    themeMode = mode;
    notifyListeners();
  }

  Future<void> setLocale(Locale? loc) async {
    final prefs = await SharedPreferences.getInstance();
    if (loc == null) {
      await prefs.remove(kPrefLocale);
    } else {
      await prefs.setString(kPrefLocale, loc.languageCode);
    }
    locale = loc;
    notifyListeners();
  }
}
