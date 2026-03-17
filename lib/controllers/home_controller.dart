import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HomeController extends ChangeNotifier {
  static const _platform = MethodChannel('com.example.hyperisland/test');

  bool isSending = false;
  bool? moduleActive; // null = 检测中

  HomeController() {
    _checkModuleActive();
  }

  Future<void> _checkModuleActive() async {
    try {
      final bool active = await _platform.invokeMethod('isModuleActive');
      moduleActive = active;
    } catch (_) {
      moduleActive = false;
    }
    notifyListeners();
  }

  Future<void> sendTest() async {
    isSending = true;
    notifyListeners();
    try {
      await _platform.invokeMethod('showTest');
    } on PlatformException catch (_) {
      // ignore
    } finally {
      isSending = false;
      notifyListeners();
    }
  }
}
