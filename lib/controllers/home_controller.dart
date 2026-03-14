import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class HomeController extends ChangeNotifier {
  static const _platform = MethodChannel('com.example.hyperisland/test');

  double progress = 0.0;
  bool isSending = false;
  bool? moduleActive; // null = 检测中
  Timer? _timer;

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

  Future<void> sendTestNotification(String type) async {
    isSending = true;
    notifyListeners();
    try {
      switch (type) {
        case 'progress':
          await _platform.invokeMethod('showProgress', {
            'title': '下载测试',
            'fileName': 'test_file.apk',
            'progress': progress.toInt(),
            'speed': '5.2 MB/s',
            'remainingTime': '00:05',
          });
        case 'complete':
          await _platform.invokeMethod('showComplete', {
            'title': '下载完成',
            'fileName': 'test_file.apk',
          });
        case 'failed':
          await _platform.invokeMethod('showFailed', {
            'title': '下载失败',
            'fileName': 'test_file.apk',
            'error': '网络连接超时',
          });
        case 'indeterminate':
          await _platform.invokeMethod('showIndeterminate', {
            'title': '准备中',
            'content': '正在连接服务器...',
          });
        case 'custom':
          await _platform.invokeMethod('showCustom', {
            'type': 'custom_notification',
            'title': '自定义通知',
            'content': '这是一个自定义的灵动岛通知',
            'icon': 'android.R.drawable.ic_dialog_info',
          });
      }
    } on PlatformException catch (_) {
      // ignore
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  void startProgressDemo() {
    progress = 0.0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      progress += 5.0;
      if (progress >= 100) {
        progress = 100;
        timer.cancel();
        sendTestNotification('complete');
      } else {
        sendTestNotification('progress');
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
