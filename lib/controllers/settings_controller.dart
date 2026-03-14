import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kPrefResumeNotification = 'pref_resume_notification';

class SettingsController extends ChangeNotifier {
  bool resumeNotification = true;
  bool loading = true;

  SettingsController() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    resumeNotification = prefs.getBool(kPrefResumeNotification) ?? true;
    loading = false;
    notifyListeners();
  }

  Future<void> setResumeNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefResumeNotification, value);
    resumeNotification = value;
    notifyListeners();
  }
}
