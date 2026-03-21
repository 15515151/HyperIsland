import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/config_io_controller.dart';
import '../controllers/settings_controller.dart';
import '../controllers/update_controller.dart';
import '../l10n/app_localizations.dart';
import '../widgets/section_label.dart';
import 'blacklist_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _ctrl = SettingsController.instance;
  bool _checkingUpdate = false;

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _onResumeNotificationChanged(bool value) async {
    await _ctrl.setResumeNotification(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.restartScopeApp),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _onUseHookAppIconChanged(bool value) async {
    await _ctrl.setUseHookAppIcon(value);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.restartScopeApp),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _onRoundIconChanged(bool value) async {
    await _ctrl.setRoundIcon(value);
  }

  Future<void> _onMarqueeFeatureChanged(bool value) async {
    await _ctrl.setMarqueeFeature(value);
  }

  void _onMarqueeSpeedChanged(double value) {
    _ctrl.setMarqueeSpeed(value.round());
  }

  Future<void> _onWrapLongTextChanged(bool value) async {
    await _ctrl.setWrapLongText(value);
  }

  // ─── 颜色定制 ───────────────────────────────────────────────────────────────

  /// 将合法的十六进制颜色字符串解析为 [Color]，失败返回 null。
  /// 支持 #RRGGBB 和 #AARRGGBB 两种格式。
  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.startsWith('#') ? hex.substring(1) : hex;
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return null;
    // 6 位时补全不透明度
    return clean.length == 6
        ? Color(0xFF000000 | value)
        : Color(value);
  }

  /// 将 [Color] 格式化为 #AARRGGBB 十六进制字符串。
  String _colorToHex(Color color) {
    final a = color.alpha.toRadixString(16).padLeft(2, '0');
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$a$r$g$b';
  }

  /// 弹出颜色输入对话框，返回用户确认的十六进制字符串，取消或清除则返回 null。
  /// [currentHex] 为当前颜色值（可为 null 表示系统默认）。
  Future<String?> _showColorPickerDialog(
    AppLocalizations l10n, {
    String? currentHex,
  }) async {
    final controller = TextEditingController(text: currentHex ?? '');
    String? errorText;
    Color previewColor = _parseHexColor(currentHex) ?? Colors.transparent;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void onTextChanged(String v) {
            final parsed = _parseHexColor(v);
            setDialogState(() {
              errorText = (v.isEmpty || parsed != null)
                  ? null
                  : l10n.colorHexInvalid;
              previewColor = parsed ?? Colors.transparent;
            });
          }

          return AlertDialog(
            title: Text(l10n.colorPickerTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 颜色预览块
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: previewColor,
                    border: Border.all(
                        color: Theme.of(ctx).colorScheme.outline, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 12),
                // 十六进制输入框
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: l10n.colorHexHint,
                    hintText: '#AARRGGBB',
                    errorText: errorText,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: onTextChanged,
                ),
              ],
            ),
            actions: [
              // 恢复默认（清除颜色）
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(''),
                child: Text(l10n.colorResetDefault),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: errorText == null && controller.text.isNotEmpty
                    ? () => Navigator.of(ctx).pop(controller.text)
                    : null,
                child: Text(l10n.confirm),
              ),
            ],
          );
        },
      ),
    );
    return result;
  }

  Future<void> _onIslandHighlightColorTap(AppLocalizations l10n) async {
    final picked = await _showColorPickerDialog(
      l10n,
      currentHex: _ctrl.islandHighlightColor,
    );
    if (picked == null) return; // 用户取消
    await _ctrl.setIslandHighlightColor(picked.isEmpty ? null : picked);
  }

  Future<void> _onFocusNotifBgColorTap(AppLocalizations l10n) async {
    final picked = await _showColorPickerDialog(
      l10n,
      currentHex: _ctrl.focusNotifBgColor,
    );
    if (picked == null) return; // 用户取消
    await _ctrl.setFocusNotifBgColor(picked.isEmpty ? null : picked);
  }

  Future<void> _onIslandBgColorTap(AppLocalizations l10n) async {
    final picked = await _showColorPickerDialog(
      l10n,
      currentHex: _ctrl.islandBgColor,
    );
    if (picked == null) return;
    await _ctrl.setIslandBgColor(picked.isEmpty ? null : picked);
  }

  /// 构建颜色预览小圆片 + 文字的行式副标题。
  Widget _buildColorSubtitle(
    BuildContext context,
    AppLocalizations l10n,
    String? hexColor,
    String descWhenSet,
  ) {
    final color = _parseHexColor(hexColor);
    if (color == null) {
      return Text(l10n.colorSystemDefault);
    }
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
                color: Theme.of(context).colorScheme.outline, width: 1),
          ),
        ),
        const SizedBox(width: 6),
        Text(hexColor!.toUpperCase()),
      ],
    );
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  String _localizeConfigIOError(AppLocalizations l10n, ConfigIOError error) {
    return switch (error) {
      ConfigIOError.invalidFormat => l10n.errorInvalidFormat,
      ConfigIOError.noStorageDirectory => l10n.errorNoStorageDir,
      ConfigIOError.noFileSelected => l10n.errorNoFileSelected,
      ConfigIOError.noFilePath => l10n.errorNoFilePath,
      ConfigIOError.emptyClipboard => l10n.errorEmptyClipboard,
    };
  }

  Future<void> _exportToFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final path = await ConfigIOController.exportToFile();
      _showSnack(l10n.exportedTo(path));
    } on ConfigIOException catch (e) {
      _showSnack(l10n.exportFailed(_localizeConfigIOError(l10n, e.error)));
    } catch (e) {
      _showSnack(l10n.exportFailed(e.toString()));
    }
  }

  Future<void> _exportToClipboard() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ConfigIOController.exportToClipboard();
      _showSnack(l10n.configCopied);
    } on ConfigIOException catch (e) {
      _showSnack(l10n.exportFailed(_localizeConfigIOError(l10n, e.error)));
    } catch (e) {
      _showSnack(l10n.exportFailed(e.toString()));
    }
  }

  Future<void> _importFromFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final count = await ConfigIOController.importFromFile();
      _showSnack(l10n.importSuccess(count));
    } on ConfigIOException catch (e) {
      _showSnack(l10n.importFailed(_localizeConfigIOError(l10n, e.error)));
    } catch (e) {
      _showSnack(l10n.importFailed(e.toString()));
    }
  }

  Future<void> _importFromClipboard() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final count = await ConfigIOController.importFromClipboard();
      _showSnack(l10n.importSuccess(count));
    } on ConfigIOException catch (e) {
      _showSnack(l10n.importFailed(_localizeConfigIOError(l10n, e.error)));
    } catch (e) {
      _showSnack(l10n.importFailed(e.toString()));
    }
  }

  Future<void> _doCheckUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        await UpdateController.checkAndShow(context, info.version,
            showUpToDate: true);
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  String _themeModeLabel(AppLocalizations l10n) => switch (_ctrl.themeMode) {
    ThemeMode.light  => l10n.themeModeLight,
    ThemeMode.dark   => l10n.themeModeDark,
    ThemeMode.system => l10n.themeModeSystem,
  };

  String _localeLabel(AppLocalizations l10n) {
    if (_ctrl.locale == null) return l10n.languageAuto;
    return switch (_ctrl.locale!.languageCode) {
      'zh' => l10n.languageZh,
      'en' => l10n.languageEn,
      'ja' => l10n.languageJa,
      _    => _ctrl.locale!.languageCode,
    };
  }

  Future<void> _showThemeModeDialog(AppLocalizations l10n) async {
    final result = await showDialog<ThemeMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.themeModeTitle),
        children: [
          _RadioOption(l10n.themeModeSystem, ThemeMode.system, _ctrl.themeMode),
          _RadioOption(l10n.themeModeLight,  ThemeMode.light,  _ctrl.themeMode),
          _RadioOption(l10n.themeModeDark,   ThemeMode.dark,   _ctrl.themeMode),
        ],
      ),
    );
    if (result != null) _ctrl.setThemeMode(result);
  }

  Future<void> _showLanguageDialog(AppLocalizations l10n) async {
    final result = await showDialog<Locale?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.languageTitle),
        children: [
          _RadioOption<Locale?>(l10n.languageAuto, null,              _ctrl.locale),
          _RadioOption<Locale?>(l10n.languageZh,   const Locale('zh'), _ctrl.locale),
          _RadioOption<Locale?>(l10n.languageEn,   const Locale('en'), _ctrl.locale),
          _RadioOption<Locale?>(l10n.languageJa,   const Locale('ja'), _ctrl.locale),
        ],
      ),
    );
    if (result != _ctrl.locale) _ctrl.setLocale(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(l10n.navSettings),
            backgroundColor: cs.surface,
            centerTitle: false,
          ),
          if (_ctrl.loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SectionLabel(l10n.navBlacklist),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16))),
                          leading: const Icon(Icons.block),
                          title: Text(l10n.navBlacklist),
                          subtitle: Text(l10n.navBlacklistSubtitle),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const BlacklistPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionLabel(l10n.behaviorSection),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(l10n.keepFocusNotifTitle),
                          subtitle: Text(l10n.keepFocusNotifSubtitle),
                          value: _ctrl.resumeNotification,
                          onChanged: _onResumeNotificationChanged,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16))),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(l10n.checkUpdateOnLaunchTitle),
                          subtitle: Text(l10n.checkUpdateOnLaunchSubtitle),
                          value: _ctrl.checkUpdateOnLaunch,
                          onChanged: _ctrl.setCheckUpdateOnLaunch,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(16))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionLabel(l10n.appearanceSection),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(l10n.useAppIconTitle),
                          subtitle: Text(l10n.useAppIconSubtitle),
                          value: _ctrl.useHookAppIcon,
                          onChanged: _onUseHookAppIconChanged,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(l10n.roundIconTitle),
                          subtitle: Text(l10n.roundIconSubtitle),
                          value: _ctrl.roundIcon,
                          onChanged: _onRoundIconChanged,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(l10n.marqueeFeatureTitle),
                          subtitle: Text(l10n.marqueeFeatureSubtitle),
                          value: _ctrl.marqueeFeature,
                          onChanged: _onMarqueeFeatureChanged,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        if (_ctrl.marqueeFeature) ...[
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(l10n.marqueeSpeedTitle,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium),
                                    Row(
                                      children: [
                                        Text(
                                          l10n.marqueeSpeedLabel(
                                              _ctrl.marqueeSpeed),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: cs.onSurfaceVariant),
                                        ),
                                        Opacity(
                                          opacity: _ctrl.marqueeSpeed != 100 ? 1.0 : 0.0,
                                          child: IconButton(
                                            icon: const Icon(Icons.refresh, size: 16),
                                            padding: EdgeInsets.zero,
                                            visualDensity: VisualDensity.compact,
                                            onPressed: _ctrl.marqueeSpeed != 100
                                                ? () => _ctrl.setMarqueeSpeed(100)
                                                : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: _ctrl.marqueeSpeed.toDouble(),
                                  min: 20,
                                  max: 500,
                                  divisions: 48,
                                  onChanged: _onMarqueeSpeedChanged,
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(l10n.wrapLongTextTitle),
                          subtitle: Text(l10n.wrapLongTextSubtitle),
                          value: _ctrl.wrapLongText,
                          onChanged: _onWrapLongTextChanged,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(l10n.themeModeTitle),
                          subtitle: Text(_themeModeLabel(l10n)),
                          onTap: () => _showThemeModeDialog(l10n),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(l10n.languageTitle),
                          subtitle: Text(_localeLabel(l10n)),
                          onTap: () => _showLanguageDialog(l10n),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(16))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ─── 颜色定制分区 ────────────────────────────────────────────
                  SectionLabel(l10n.islandColorSection),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        // 超级岛边框高亮颜色
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16))),
                          title: Text(l10n.islandHighlightColorTitle),
                          subtitle: _buildColorSubtitle(
                            context,
                            l10n,
                            _ctrl.islandHighlightColor,
                            _ctrl.islandHighlightColor ?? '',
                          ),
                          trailing: _ctrl.islandHighlightColor != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: l10n.colorResetDefault,
                                  onPressed: () =>
                                      _ctrl.setIslandHighlightColor(null),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () => _onIslandHighlightColorTap(l10n),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        // 焦点通知背景颜色
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          title: Text(l10n.focusNotifBgColorTitle),
                          subtitle: _buildColorSubtitle(
                            context,
                            l10n,
                            _ctrl.focusNotifBgColor,
                            _ctrl.focusNotifBgColor ?? '',
                          ),
                          trailing: _ctrl.focusNotifBgColor != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: l10n.colorResetDefault,
                                  onPressed: () =>
                                      _ctrl.setFocusNotifBgColor(null),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () => _onFocusNotifBgColorTap(l10n),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        // 超级岛背景填充色
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(16))),
                          title: Text(l10n.islandBgColorTitle),
                          subtitle: _buildColorSubtitle(
                            context,
                            l10n,
                            _ctrl.islandBgColor,
                            _ctrl.islandBgColor ?? '',
                          ),
                          trailing: _ctrl.islandBgColor != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  tooltip: l10n.colorResetDefault,
                                  onPressed: () =>
                                      _ctrl.setIslandBgColor(null),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: () => _onIslandBgColorTap(l10n),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionLabel(l10n.configSection),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16))),
                          leading: const Icon(Icons.upload_file_outlined),
                          title: Text(l10n.exportToFile),
                          subtitle: Text(l10n.exportToFileSubtitle),
                          onTap: _exportToFile,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: const Icon(Icons.copy_outlined),
                          title: Text(l10n.exportToClipboard),
                          subtitle: Text(l10n.exportToClipboardSubtitle),
                          onTap: _exportToClipboard,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: const Icon(Icons.download_outlined),
                          title: Text(l10n.importFromFile),
                          subtitle: Text(l10n.importFromFileSubtitle),
                          onTap: _importFromFile,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(16))),
                          leading: const Icon(Icons.paste_outlined),
                          title: Text(l10n.importFromClipboard),
                          subtitle: Text(l10n.importFromClipboardSubtitle),
                          onTap: _importFromClipboard,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionLabel(l10n.aboutSection),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.system_update_outlined),
                          title: Text(l10n.checkUpdate),
                          trailing: _checkingUpdate
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                            CircularProgressIndicator(strokeWidth: 2),
                          )
                              : null,
                          onTap: _checkingUpdate ? null : _doCheckUpdate,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(16))),
                          leading: const Icon(Icons.code),
                          title: const Text('GitHub'),
                          subtitle: const Text('1812z/HyperIsland'),
                          trailing: const Icon(Icons.open_in_new, size: 18),
                          onTap: () => launchUrl(
                            Uri.parse('https://github.com/1812z/HyperIsland'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(16))),
                          leading: const Icon(Icons.group_outlined),
                          title: Text(l10n.qqGroup),
                          subtitle: const Text('1045114341'),
                          trailing: const Icon(Icons.copy, size: 18),
                          onTap: () {
                            Clipboard.setData(
                                const ClipboardData(text: '1045114341'));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.groupNumberCopied),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Generic radio option for SimpleDialog — pops the dialog with [value].
class _RadioOption<T> extends StatelessWidget {
  const _RadioOption(this.label, this.value, this.groupValue, {super.key});

  final String label;
  final T value;
  final T groupValue;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      title: Text(label),
      value: value,
      groupValue: groupValue,
      onChanged: (_) => Navigator.of(context).pop(value),
    );
  }
}
