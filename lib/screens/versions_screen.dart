import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/game_version.dart';
import '../models/config.dart';
import '../l10n/app_localizations.dart';

class VersionsScreen extends StatefulWidget {
  const VersionsScreen({super.key});

  @override
  State<VersionsScreen> createState() => _VersionsScreenState();
}

class _VersionsScreenState extends State<VersionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showSnapshots = false;
  bool _showOldVersions = false;
  String? _selectedVersionForDetails;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GameService>().refreshVersions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameService = context.watch<GameService>();
    final isWide = MediaQuery.of(context).size.width > 900;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: isWide 
          ? _buildWideLayout(gameService)
          : _buildNarrowLayout(gameService),
    );
  }

  Widget _buildWideLayout(GameService gameService) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Expanded(
          flex: 2,
          child: _buildVersionList(gameService),
        ),
        const SizedBox(width: 24),
        
        Expanded(
          flex: 1,
          child: _selectedVersionForDetails != null
              ? _buildVersionDetails(gameService, _selectedVersionForDetails!)
              : _buildNoSelectionHint(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(GameService gameService) {
    return _buildVersionList(gameService);
  }

  Widget _buildVersionList(GameService gameService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('版本管理', style: Theme.of(context).textTheme.headlineMedium),
            Row(
              children: [
                IconButton(
                  onPressed: () => gameService.refreshVersions(),
                  icon: gameService.isLoading
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary))
                      : const Icon(Icons.refresh),
                  tooltip: '刷新',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Theme.of(context).colorScheme.onPrimaryContainer,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            tabs: const [Tab(text: '已安装'), Tab(text: '可下载')],
          ),
        ),
        const SizedBox(height: 16),
        
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInstalledTab(gameService),
              _buildAvailableTab(gameService),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInstalledTab(GameService gameService) {
    final versions = gameService.installedVersions;
    if (versions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.folder_off, size: 40, color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Text('暂无已安装版本', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('切换到"可下载"标签页安装游戏', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: versions.length,
      itemBuilder: (context, index) {
        final version = versions[index];
        final profile = gameService.getVersionProfile(version.id);
        final isSelected = version.id == gameService.selectedVersion;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3) : null,
          child: InkWell(
            onTap: () {
              gameService.selectVersion(version.id);
              setState(() => _selectedVersionForDetails = version.id);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.games,
                      color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? version.id,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildBadge(version.type),
                            if (version.javaVersion != null) ...[
                              const SizedBox(width: 8),
                              _buildBadge('Java ${version.javaVersion}'),
                            ],
                            if (profile?.isolation != IsolationType.none) ...[
                              const SizedBox(width: 8),
                              _buildBadge('隔离'),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) => _handleVersionAction(action, version.id),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings), title: Text('版本设置'), dense: true)),
                      const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit), title: Text('重命名'), dense: true)),
                      const PopupMenuItem(value: 'duplicate', child: ListTile(leading: Icon(Icons.copy), title: Text('复制'), dense: true)),
                      const PopupMenuItem(value: 'backup', child: ListTile(leading: Icon(Icons.archive), title: Text('备份'), dense: true)),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('删除', style: TextStyle(color: Colors.red)), dense: true)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  void _handleVersionAction(String action, String versionId) async {
    switch (action) {
      case 'settings':
        _showVersionSettings(versionId);
        break;
      case 'rename':
        _showRenameDialog(versionId);
        break;
      case 'duplicate':
        _showDuplicateDialog(versionId);
        break;
      case 'backup':
        _backupVersion(versionId);
        break;
      case 'delete':
        _showDeleteDialog(versionId);
        break;
    }
  }

  Widget _buildVersionDetails(GameService gameService, String versionId) {
    final version = gameService.getInstalledVersion(versionId);
    final profile = gameService.getVersionProfile(versionId);
    
    if (version == null) return _buildNoSelectionHint();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.games, size: 28, color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.displayName ?? version.id, style: Theme.of(context).textTheme.titleLarge),
                      Text(version.type, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow('版本 ID', version.id),
            _buildDetailRow('类型', version.type),
            if (version.inheritsFrom != null) _buildDetailRow('继承自', version.inheritsFrom!),
            if (version.javaVersion != null) _buildDetailRow('Java 版本', 'Java ${version.javaVersion}'),
            _buildDetailRow('版本隔离', _getIsolationName(profile?.isolation ?? IsolationType.none)),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showVersionSettings(versionId),
                    icon: const Icon(Icons.settings),
                    label: const Text('设置'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      gameService.selectVersion(versionId);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已选择 ${profile?.displayName ?? versionId}')));
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('选择'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _getIsolationName(IsolationType type) => switch (type) {
    IsolationType.none => '不隔离',
    IsolationType.partial => '部分隔离',
    IsolationType.full => '完全隔离',
  };

  Widget _buildNoSelectionHint() {
    return Card(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('选择一个版本查看详情', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  void _showVersionSettings(String versionId) {
    showDialog(context: context, builder: (context) => _VersionSettingsDialog(versionId: versionId));
  }

  void _showRenameDialog(String versionId) {
    final controller = TextEditingController(text: versionId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名版本'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: '新名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty && controller.text != versionId) {
                try {
                  await context.read<GameService>().renameVersion(versionId, controller.text);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('重命名失败: $e')));
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateDialog(String versionId) {
    final controller = TextEditingController(text: '$versionId-copy');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('复制版本'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: '新版本名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  await context.read<GameService>().duplicateVersion(versionId, controller.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('复制完成')));
                  }
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('复制失败: $e')));
                }
              }
            },
            child: const Text('复制'),
          ),
        ],
      ),
    );
  }

  void _backupVersion(String versionId) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在备份...')));
    try {
      final path = await context.read<GameService>().backupVersion(versionId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('备份完成: $path')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('备份失败: $e')));
    }
  }

  void _showDeleteDialog(String versionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除版本'),
        content: Text('确定要删除 "$versionId" 吗？\n文件将移动到回收站。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              await context.read<GameService>().deleteVersion(versionId);
              if (context.mounted) {
                Navigator.pop(context);
                setState(() => _selectedVersionForDetails = null);
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableTab(GameService gameService) {
    return Column(
      children: [
        
        Row(
          children: [
            FilterChip(label: const Text('快照版'), selected: _showSnapshots, onSelected: (v) => setState(() => _showSnapshots = v)),
            const SizedBox(width: 8),
            FilterChip(label: const Text('远古版'), selected: _showOldVersions, onSelected: (v) => setState(() => _showOldVersions = v)),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildAvailableVersionList(gameService)),
      ],
    );
  }

  Widget _buildAvailableVersionList(GameService gameService) {
    final versions = gameService.availableVersions.where((v) {
      if (v.type == 'release') return true;
      if (v.type == 'snapshot' && _showSnapshots) return true;
      if ((v.type == 'old_beta' || v.type == 'old_alpha') && _showOldVersions) return true;
      return false;
    }).toList();

    if (versions.isEmpty) {
      return Center(
        child: gameService.isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('无法获取版本列表'),
                  const SizedBox(height: 8),
                  FilledButton.tonal(onPressed: () => gameService.refreshVersions(), child: const Text('重试')),
                ],
              ),
      );
    }

    return ListView.builder(
      itemCount: versions.length,
      itemBuilder: (context, index) {
        final version = versions[index];
        final isInstalled = gameService.installedVersions.any((v) => v.id == version.id || v.inheritsFrom == version.id);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getVersionIcon(version.versionType), color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            title: Text(version.id),
            subtitle: Text('${_getVersionTypeName(version.versionType)} • ${_formatDate(version.releaseTime)}'),
            trailing: isInstalled
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('已安装', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  )
                : FilledButton.tonal(onPressed: () => _showInstallDialog(version), child: const Text('安装')),
          ),
        );
      },
    );
  }

  IconData _getVersionIcon(VersionType type) => switch (type) {
    VersionType.release => Icons.check_circle,
    VersionType.snapshot => Icons.science,
    VersionType.oldBeta => Icons.history,
    VersionType.oldAlpha => Icons.history_toggle_off,
  };

  String _getVersionTypeName(VersionType type) {
    final l10n = AppLocalizations.of(context);
    return switch (type) {
      VersionType.release => l10n.get('type_release'),
      VersionType.snapshot => l10n.get('type_snapshot'),
      VersionType.oldBeta => l10n.get('type_old_beta'),
      VersionType.oldAlpha => l10n.get('type_old_alpha'),
    };
  }

  String _formatDate(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _showInstallDialog(GameVersion version) {
    showDialog(
      context: context, 
      barrierDismissible: false,  
      builder: (context) => _InstallVersionDialog(version: version),
    );
  }
}

class _VersionSettingsDialog extends StatefulWidget {
  final String versionId;
  const _VersionSettingsDialog({required this.versionId});

  @override
  State<_VersionSettingsDialog> createState() => _VersionSettingsDialogState();
}

class _VersionSettingsDialogState extends State<_VersionSettingsDialog> {
  late VersionProfile _profile;
  bool _useCustomJava = false;
  bool _useCustomMemory = false;

  @override
  void initState() {
    super.initState();
    final gameService = context.read<GameService>();
    _profile = gameService.getVersionProfile(widget.versionId) ?? VersionProfile(versionId: widget.versionId);
    _useCustomJava = _profile.javaPath != null;
    _useCustomMemory = _profile.maxMemory != null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${_profile.displayName} 设置'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: '显示名称'),
                controller: TextEditingController(text: _profile.displayName),
                onChanged: (v) => _profile.displayName = v,
              ),
              const SizedBox(height: 16),
              Text('版本隔离', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<IsolationType>(
                segments: const [
                  ButtonSegment(value: IsolationType.none, label: Text('不隔离')),
                  ButtonSegment(value: IsolationType.partial, label: Text('部分')),
                  ButtonSegment(value: IsolationType.full, label: Text('完全')),
                ],
                selected: {_profile.isolation},
                onSelectionChanged: (s) => setState(() => _profile.isolation = s.first),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('自定义 Java'),
                value: _useCustomJava,
                onChanged: (v) => setState(() {
                  _useCustomJava = v;
                  if (!v) _profile.javaPath = null;
                }),
              ),
              if (_useCustomJava)
                TextField(
                  decoration: const InputDecoration(labelText: 'Java 路径'),
                  controller: TextEditingController(text: _profile.javaPath),
                  onChanged: (v) => _profile.javaPath = v,
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('自定义内存'),
                value: _useCustomMemory,
                onChanged: (v) => setState(() {
                  _useCustomMemory = v;
                  if (!v) {
                    _profile.minMemory = null;
                    _profile.maxMemory = null;
                  }
                }),
              ),
              if (_useCustomMemory) ...[
                Text('最大内存: ${_profile.maxMemory ?? 4096} MB'),
                Slider(
                  value: (_profile.maxMemory ?? 4096).toDouble(),
                  min: 512,
                  max: 16384,
                  divisions: 31,
                  onChanged: (v) => setState(() => _profile.maxMemory = v.toInt()),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () async {
            await context.read<GameService>().saveVersionProfile(_profile);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _InstallVersionDialog extends StatefulWidget {
  final GameVersion version;
  const _InstallVersionDialog({required this.version});

  @override
  State<_InstallVersionDialog> createState() => _InstallVersionDialogState();
}

class _InstallVersionDialogState extends State<_InstallVersionDialog> {
  bool _isLoading = false;
  bool _isInstalling = false;
  String _status = '';
  double _progress = 0;

  final _nameController = TextEditingController();
  String? _selectedFabric;
  String? _selectedForge;
  String? _selectedQuilt;
  String? _selectedOptiFine;
  IsolationType _isolation = IsolationType.none;

  List<ModLoaderVersion> _fabricVersions = [];
  List<ModLoaderVersion> _forgeVersions = [];
  List<ModLoaderVersion> _quiltVersions = [];
  List<ModLoaderVersion> _optiFineVersions = [];

  int _selectedLoader = 0;
  bool _installOptiFine = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.version.id;
    _loadModLoaderVersions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadModLoaderVersions() async {
    setState(() => _isLoading = true);
    final gameService = context.read<GameService>();
    
    final results = await Future.wait([
      gameService.getFabricVersions(widget.version.id),
      gameService.getForgeVersions(widget.version.id),
      gameService.getQuiltVersions(widget.version.id),
      gameService.getOptiFineVersions(widget.version.id),
    ]);

    setState(() {
      _fabricVersions = results[0];
      _forgeVersions = results[1];
      _quiltVersions = results[2];
      _optiFineVersions = results[3];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('安装 ${widget.version.id}'),
      content: SizedBox(width: 500, child: _isInstalling ? _buildInstallingView() : _buildOptionsView()),
      actions: _isInstalling ? null : [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: _install, child: const Text('安装')),
      ],
    );
  }

  Widget _buildOptionsView() {
    if (_isLoading) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: '版本名称')),
          const SizedBox(height: 16),
          Text('版本隔离', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<IsolationType>(
            segments: const [
              ButtonSegment(value: IsolationType.none, label: Text('不隔离')),
              ButtonSegment(value: IsolationType.partial, label: Text('部分')),
              ButtonSegment(value: IsolationType.full, label: Text('完全')),
            ],
            selected: {_isolation},
            onSelectionChanged: (s) => setState(() => _isolation = s.first),
          ),
          const SizedBox(height: 16),
          Text('Mod 加载器', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              const ButtonSegment(value: 0, label: Text('无')),
              ButtonSegment(value: 1, label: const Text('Fabric'), enabled: _fabricVersions.isNotEmpty),
              ButtonSegment(value: 2, label: const Text('Forge'), enabled: _forgeVersions.isNotEmpty),
              ButtonSegment(value: 3, label: const Text('Quilt'), enabled: _quiltVersions.isNotEmpty),
            ],
            selected: {_selectedLoader},
            onSelectionChanged: (s) => setState(() {
              _selectedLoader = s.first;
              _updateVersionName();
            }),
          ),
          const SizedBox(height: 16),
          if (_selectedLoader == 1 && _fabricVersions.isNotEmpty) _buildLoaderDropdown('Fabric', _fabricVersions, _selectedFabric, (v) => setState(() { _selectedFabric = v; _updateVersionName(); })),
          if (_selectedLoader == 2 && _forgeVersions.isNotEmpty) _buildLoaderDropdown('Forge', _forgeVersions, _selectedForge, (v) => setState(() { _selectedForge = v; _updateVersionName(); })),
          if (_selectedLoader == 3 && _quiltVersions.isNotEmpty) _buildLoaderDropdown('Quilt', _quiltVersions, _selectedQuilt, (v) => setState(() { _selectedQuilt = v; _updateVersionName(); })),
          
          if (_optiFineVersions.isNotEmpty && _selectedLoader != 1 && _selectedLoader != 3) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('安装 OptiFine'),
              subtitle: const Text('优化性能和光影支持'),
              value: _installOptiFine,
              onChanged: (v) => setState(() {
                _installOptiFine = v ?? false;
                _updateVersionName();
              }),
            ),
            if (_installOptiFine) ...[
              const SizedBox(height: 12),
              _buildLoaderDropdown('OptiFine', _optiFineVersions, _selectedOptiFine, (v) => setState(() { _selectedOptiFine = v; _updateVersionName(); })),
            ],
          ],
        ],
      ),
    );
  }

  void _updateVersionName() {
    String name = widget.version.id;
    if (_selectedLoader == 1 && _selectedFabric != null) name = '${widget.version.id}-fabric-$_selectedFabric';
    if (_selectedLoader == 2 && _selectedForge != null) name = '${widget.version.id}-forge-$_selectedForge';
    if (_selectedLoader == 3 && _selectedQuilt != null) name = '${widget.version.id}-quilt-$_selectedQuilt';
    if (_installOptiFine && _selectedOptiFine != null) name = '$name-OptiFine-$_selectedOptiFine';
    _nameController.text = name;
  }

  Widget _buildLoaderDropdown(String label, List<ModLoaderVersion> versions, String? selected, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: selected ?? (versions.isNotEmpty ? versions.first.version : null),
      decoration: InputDecoration(labelText: '$label 版本'),
      items: versions.map((v) => DropdownMenuItem(value: v.version, child: Text('${v.version}${v.stable ? ' (推荐)' : ''}'))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildInstallingView() {
    return SizedBox(
      height: 150,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: 16),
          Text(_status, textAlign: TextAlign.center),
          if (_progress > 0) Text('${(_progress * 100).toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Future<void> _install() async {
    
    if (_selectedLoader == 1) _selectedFabric ??= _fabricVersions.isNotEmpty ? _fabricVersions.first.version : null;
    if (_selectedLoader == 2) _selectedForge ??= _forgeVersions.isNotEmpty ? _forgeVersions.first.version : null;
    if (_selectedLoader == 3) _selectedQuilt ??= _quiltVersions.isNotEmpty ? _quiltVersions.first.version : null;
    if (_installOptiFine) _selectedOptiFine ??= _optiFineVersions.isNotEmpty ? _optiFineVersions.first.version : null;

    
    debugPrint('[Install UI] _selectedLoader=$_selectedLoader');
    debugPrint('[Install UI] _selectedFabric=$_selectedFabric');
    debugPrint('[Install UI] _selectedForge=$_selectedForge');
    debugPrint('[Install UI] _selectedQuilt=$_selectedQuilt');
    debugPrint('[Install UI] _fabricVersions.length=${_fabricVersions.length}');
    debugPrint('[Install UI] _forgeVersions.length=${_forgeVersions.length}');
    debugPrint('[Install UI] _quiltVersions.length=${_quiltVersions.length}');

    setState(() { _isInstalling = true; _status = '准备安装...'; _progress = 0; });

    try {
      final gameService = context.read<GameService>();
      
      
      final fabricVersion = _selectedLoader == 1 ? _selectedFabric : null;
      final forgeVersion = _selectedLoader == 2 ? _selectedForge : null;
      final quiltVersion = _selectedLoader == 3 ? _selectedQuilt : null;
      
      final optifineVersion = _installOptiFine && _selectedOptiFine != null && _selectedLoader != 1 && _selectedLoader != 3
          ? _selectedOptiFine
          : null;
      
      debugPrint('[Install UI] 传递参数: fabric=$fabricVersion, forge=$forgeVersion, quilt=$quiltVersion, optifine=$optifineVersion');
      
      
      await gameService.installVersion(
        widget.version,
        customName: _nameController.text != widget.version.id ? _nameController.text : null,
        fabric: fabricVersion,
        forge: forgeVersion,
        quilt: quiltVersion,
        optifine: optifineVersion,
        isolation: _isolation,
        onStatus: (s) => setState(() => _status = s),
        onProgress: (p) => setState(() => _progress = p),
      );
      
      
      if (_installOptiFine && _selectedOptiFine != null && (_selectedLoader == 1 || _selectedLoader == 3)) {
        final baseVersionId = _nameController.text;
        setState(() => _status = '正在安装 OptiFine（独立版本）...');
        try {
          await gameService.installOptiFine(
            baseVersionId,
            _selectedOptiFine!,
            onStatus: (s) => setState(() => _status = s),
            onProgress: (p) => setState(() => _progress = p),
          );
        } catch (e, stack) {
          debugPrint('[Install UI] OptiFine 安装失败: $e\n$stack');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('OptiFine 安装失败: $e'), backgroundColor: Colors.orange),
            );
          }
        }
      }
      
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_nameController.text} 安装完成')));
    } catch (e, stack) {
      debugPrint('[Install UI] 安装失败: $e\n$stack');
      setState(() { _isInstalling = false; _status = '安装失败: $e'; });
    }
  }
}
