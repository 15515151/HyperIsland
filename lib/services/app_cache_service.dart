import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppInfo {
  final String packageName;
  final String appName;
  final Uint8List icon;
  final bool isSystem;

  const AppInfo({
    required this.packageName,
    required this.appName,
    required this.icon,
    this.isSystem = false,
  });
}

class AppCacheService extends ChangeNotifier {
  static final AppCacheService instance = AppCacheService._();
  AppCacheService._();

  static const _channel = MethodChannel('io.github.hyperisland/test');

  List<AppInfo> _cachedApps = [];
  bool _loading = false;
  bool _initialized = false;
  DateTime? _lastLoadTime;
  Future<void>? _loadFuture;

  static const _cacheValidDuration = Duration(minutes: 5);

  List<AppInfo> get apps => _cachedApps;
  bool get loading => _loading;
  bool get initialized => _initialized;

  static const _excludedPackages = {
    "com.android.providers.downloads.ui"

  };

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await loadApps();
  }

  Future<List<AppInfo>> getApps({bool forceRefresh = false}) async {
    if (_loading && _loadFuture != null) {
      await _loadFuture;
      return _cachedApps;
    }
    if (forceRefresh || _shouldRefresh()) {
      await loadApps();
    }
    return _cachedApps;
  }

  bool _shouldRefresh() {
    if (_cachedApps.isEmpty) return true;
    if (_lastLoadTime == null) return true;
    return DateTime.now().difference(_lastLoadTime!) > _cacheValidDuration;
  }

  Future<void> loadApps() {
    if (_loading) return _loadFuture ?? Future.value();
    _loadFuture = _doLoadApps();
    return _loadFuture!;
  }

  Future<void> _doLoadApps() async {
    _loading = true;
    notifyListeners();

    try {
      final rawList =
          await _channel.invokeMethod<List<dynamic>>('getInstalledApps', {
            'includeSystem': true,
          }) ??
          [];

      _cachedApps = rawList
          .map((raw) {
            final map = Map<String, dynamic>.from(raw as Map);
            return AppInfo(
              packageName: map['packageName'] as String,
              appName: map['appName'] as String,
              icon: Uint8List.fromList((map['icon'] as List).cast<int>()),
              isSystem: map['isSystem'] as bool? ?? false,
            );
          })
          .where((a) => !_excludedPackages.contains(a.packageName))
          .toList();

      _lastLoadTime = DateTime.now();
    } catch (e) {
      debugPrint('AppCacheService.loadApps error: $e');
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadApps();
  }

  void clearCache() {
    _cachedApps = [];
    _lastLoadTime = null;
    notifyListeners();
  }
}
