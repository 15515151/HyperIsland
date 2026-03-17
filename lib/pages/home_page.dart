import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../controllers/home_controller.dart';
import '../widgets/section_label.dart';

const _channel = MethodChannel('com.example.hyperisland/test');

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _ctrl;
  bool _restarting = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _ctrl = HomeController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _showRestartDialog() async {
    bool restartSystemUI = true;
    bool restartDownloadManager = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('重启作用域'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                title: const Text('系统界面'),
                subtitle: const Text('com.android.systemui'),
                value: restartSystemUI,
                onChanged: (v) =>
                    setDialogState(() => restartSystemUI = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('下载管理器'),
                subtitle: const Text('com.android.providers.downloads'),
                value: restartDownloadManager,
                onChanged: (v) =>
                    setDialogState(() => restartDownloadManager = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (!restartSystemUI && !restartDownloadManager) return;

    setState(() => _restarting = true);
    try {
      final commands = <String>[];
      if (restartSystemUI) commands.add('killall com.android.systemui');
      if (restartDownloadManager) {
        commands.add('am force-stop com.android.providers.downloads');
      }
      await _channel.invokeMethod('restartProcesses', {'commands': commands});
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重启失败：${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _restarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('HyperIsland'),
                if (_version.isNotEmpty)
                  Text(
                    _version,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
            backgroundColor: cs.surface,
            centerTitle: false,
            actions: [
              _restarting
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: '重启作用域',
                      icon: const Icon(Icons.restart_alt),
                      onPressed: _showRestartDialog,
                    ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ModuleStatusCard(active: _ctrl.moduleActive),
                const SizedBox(height: 16),

                const SectionLabel('通知测试'),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _ctrl.isSending ? null : _ctrl.sendTest,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('发送测试通知'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                const SectionLabel('注意事项'),
                const SizedBox(height: 8),
                const _NotesCard(),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 页面专属组件 ──────────────────────────────────────────────────────────────

class _ModuleStatusCard extends StatelessWidget {
  final bool? active;
  const _ModuleStatusCard({required this.active});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (active == null) {
      return Card(
        elevation: 0,
        color: cs.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('正在检测模块状态...'),
            ],
          ),
        ),
      );
    }

    final bool isActive = active!;
    final color = isActive ? Colors.green : cs.error;
    final bgColor = isActive
        ? Colors.green.withValues(alpha: 0.12)
        : cs.errorContainer;

    return Card(
      elevation: 0,
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.check_circle : Icons.cancel,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '模块状态',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: color.withValues(alpha: 0.8),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive ? '已激活' : '未激活',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (!isActive) ...[
                    const SizedBox(height: 4),
                    Text(
                      '请在 LSPosed 中启用本模块',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: color.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard();

  static const _items = [
    '1.此页面仅用于测试是否支持超级岛，并不代表实际效果',
    '2.请在 HyperCeiler 中关闭系统界面和小米服务框架的焦点通知白名单',
    '3.LSPosed 管理器中激活后，必须重启相关作用域软件',
    '4.支持通用适配，自行勾选合适的模板尝试',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _items
              .map(
                (text) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.arrow_right,
                          size: 20, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          text,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
