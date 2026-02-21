import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/install_service.dart';
import '../services/paste_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

enum _SetupPreference { apiFirst, localFirst }

class SetupWizardScreen extends StatefulWidget {
  final PasteService pasteService;
  final InstallService installService;
  final String asrProviderKey;
  final ValueChanged<String>? onAsrProviderKeyChanged;
  final String modelDownloadSource;
  final String modelDownloadMirrorUrl;
  final Future<void> Function(String source, String mirrorUrl)?
  onModelDownloadConfigChanged;
  final Future<void> Function() onComplete;
  final VoidCallback onSkip;

  const SetupWizardScreen({
    super.key,
    required this.pasteService,
    required this.installService,
    this.asrProviderKey = 'iflytek',
    this.onAsrProviderKeyChanged,
    this.modelDownloadSource = 'auto',
    this.modelDownloadMirrorUrl = '',
    this.onModelDownloadConfigChanged,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;
  late _SetupPreference _setupPreference;

  // ── Step 1: Dependencies ──
  bool? _soxAvailable;
  bool? _funasrAvailable;
  bool? _homebrewAvailable;
  bool? _pythonAvailable;
  bool? _modelsDownloaded;
  bool _installingSox = false;
  bool _installingFunasr = false;
  bool _downloadingModels = false;
  double _modelsDownloadProgress = 0.0;
  String? _modelsDownloadLabel;
  final StringBuffer _soxLog = StringBuffer();
  final StringBuffer _funasrLog = StringBuffer();
  final StringBuffer _modelsLog = StringBuffer();
  final ScrollController _soxScrollCtrl = ScrollController();
  final ScrollController _funasrScrollCtrl = ScrollController();
  final ScrollController _modelsScrollCtrl = ScrollController();

  // ── Step 2: Permissions ──
  bool? _microphoneGranted;
  bool? _accessibilityGranted;
  Timer? _permissionPollTimer;
  late final TextEditingController _modelMirrorUrlController;

  static const List<({String key, String label})> _modelSourceOptions = [
    (key: 'auto', label: 'ModelScope 默认源'),
    (key: 'hf_official', label: 'HuggingFace 官方'),
    (key: 'hf_mirror', label: 'HuggingFace 镜像（推荐）'),
    (key: 'custom_hf_mirror', label: '自定义 HuggingFace 镜像'),
  ];

  String get _selectedModelSource => widget.modelDownloadSource;
  String get _effectiveMirrorUrl {
    if (_selectedModelSource == 'hf_mirror') return 'https://hf-mirror.com';
    if (_selectedModelSource == 'custom_hf_mirror') {
      return _modelMirrorUrlController.text.trim();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _setupPreference = _SetupPreference.apiFirst;
    _modelMirrorUrlController = TextEditingController(
      text: widget.modelDownloadMirrorUrl,
    );
    if (widget.asrProviderKey == 'local') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onAsrProviderKeyChanged?.call('iflytek');
      });
    }
  }

  @override
  void didUpdateWidget(covariant SetupWizardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelDownloadMirrorUrl != widget.modelDownloadMirrorUrl &&
        _modelMirrorUrlController.text != widget.modelDownloadMirrorUrl) {
      _modelMirrorUrlController.text = widget.modelDownloadMirrorUrl;
    }
    if (oldWidget.asrProviderKey != widget.asrProviderKey) {
      _setupPreference = widget.asrProviderKey == 'local'
          ? _SetupPreference.localFirst
          : _SetupPreference.apiFirst;
    }
  }

  @override
  void dispose() {
    _permissionPollTimer?.cancel();
    _soxScrollCtrl.dispose();
    _funasrScrollCtrl.dispose();
    _modelsScrollCtrl.dispose();
    _modelMirrorUrlController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    if (step == 1) _checkDependencies();
    if (step == 2) _startPermissionPolling();
    if (step != 2) _permissionPollTimer?.cancel();
  }

  void _selectSetupPreference(_SetupPreference preference) {
    if (_setupPreference == preference) return;
    setState(() => _setupPreference = preference);

    final callback = widget.onAsrProviderKeyChanged;
    if (callback == null) return;
    if (preference == _SetupPreference.localFirst) {
      callback('local');
      return;
    }
    callback(
      widget.asrProviderKey == 'local' ? 'iflytek' : widget.asrProviderKey,
    );
  }

  String? _consoleUrlForProvider(String providerKey) {
    switch (providerKey) {
      case 'iflytek':
        return 'https://console.xfyun.cn';
      case 'siliconflow':
        return 'https://siliconflow.cn';
      case 'openai':
        return 'https://platform.openai.com';
      case 'groq':
        return 'https://console.groq.com';
      default:
        return null;
    }
  }

  Future<void> _openExternalUrl(String url) async {
    try {
      final result = await Process.run('open', [url]);
      if (result.exitCode != 0) {
        debugPrint('[Setup] open url failed: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('[Setup] open url exception: $e');
    }
  }

  Future<void> _checkDependencies() async {
    final status = await widget.installService.checkAll();
    if (!mounted) return;
    setState(() {
      _homebrewAvailable = status.homebrewAvailable;
      _soxAvailable = status.soxAvailable;
      _pythonAvailable = status.pythonAvailable;
      _funasrAvailable = status.funasrAvailable;
      _modelsDownloaded = status.modelsDownloaded;
    });
  }

  Future<void> _installSox() async {
    setState(() {
      _installingSox = true;
      _soxLog.clear();
    });
    final success = await widget.installService.installSox(
      onOutput: (line) {
        if (!mounted) return;
        setState(() => _soxLog.write(line));
        _scrollToBottom(_soxScrollCtrl);
      },
    );
    if (!mounted) return;
    setState(() {
      _installingSox = false;
      if (success) _soxAvailable = true;
    });
  }

  Future<void> _installFunasr() async {
    setState(() {
      _installingFunasr = true;
      _funasrLog.clear();
    });
    final success = await widget.installService.installFunasrEnv(
      onOutput: (line) {
        if (!mounted) return;
        setState(() => _funasrLog.write(line));
        _scrollToBottom(_funasrScrollCtrl);
      },
    );
    if (!mounted) return;
    setState(() {
      _installingFunasr = false;
      if (success) _funasrAvailable = true;
    });
  }

  Future<void> _downloadModels() async {
    setState(() {
      _downloadingModels = true;
      _modelsLog.clear();
      _modelsDownloadProgress = 0.0;
      _modelsDownloadLabel = null;
    });
    final success = await widget.installService.downloadModels(
      onOutput: (line) {
        if (!mounted) return;
        setState(() => _modelsLog.write(line));
        _scrollToBottom(_modelsScrollCtrl);
      },
      onProgress: (progress, label) {
        if (!mounted) return;
        setState(() {
          _modelsDownloadProgress = progress;
          _modelsDownloadLabel = label;
        });
      },
      source: _selectedModelSource,
      hfMirrorUrl: _effectiveMirrorUrl,
    );
    if (!mounted) return;
    setState(() {
      _downloadingModels = false;
      if (success) _modelsDownloaded = true;
    });
  }

  void _scrollToBottom(ScrollController ctrl) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctrl.hasClients) {
        ctrl.jumpTo(ctrl.position.maxScrollExtent);
      }
    });
  }

  void _startPermissionPolling() {
    _pollPermissions();
    _permissionPollTimer?.cancel();
    _permissionPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _pollPermissions(),
    );
  }

  Future<void> _pollPermissions() async {
    final mic = await widget.pasteService.checkMicrophonePermission();
    final a11y = await widget.pasteService.checkAccessibilityPermission();
    if (!mounted) return;
    setState(() {
      _microphoneGranted = mic;
      _accessibilityGranted = a11y;
    });
  }

  Future<void> _requestMicrophone() async {
    final granted = await widget.pasteService.requestMicrophonePermission();
    if (!granted) await widget.pasteService.openMicrophoneSettings();
    await Future.delayed(const Duration(milliseconds: 300));
    await _pollPermissions();
  }

  Future<void> _openAccessibilitySettings() async {
    await widget.pasteService.openAccessibilitySettings();
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: _buildPanel());
  }

  Widget _buildPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Column(
            children: [
              _buildStepIndicator(),
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppTheme.borderDefault,
              ),
              Expanded(child: _buildStepContent()),
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppTheme.borderDefault,
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step indicator ─────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    const labels = ['欢迎', '依赖', '权限', '完成'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i == _step;
          final isDone = i < _step;
          return Expanded(
            child: Row(
              children: [
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: isDone
                            ? const LinearGradient(
                                colors: [
                                  AppTheme.accentPrimary,
                                  AppTheme.accentSecondary,
                                ],
                              )
                            : null,
                        color: isDone ? null : AppTheme.borderDefault,
                      ),
                    ),
                  ),
                _stepDot(
                  index: i,
                  isActive: isActive,
                  isDone: isDone,
                  label: labels[i],
                ),
                if (i < labels.length - 1)
                  Expanded(
                    child: Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        gradient: i < _step
                            ? const LinearGradient(
                                colors: [
                                  AppTheme.accentPrimary,
                                  AppTheme.accentSecondary,
                                ],
                              )
                            : null,
                        color: i < _step ? null : AppTheme.borderDefault,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _stepDot({
    required int index,
    required bool isActive,
    required bool isDone,
    required String label,
  }) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isDone
            ? const LinearGradient(
                colors: [AppTheme.accentPrimary, AppTheme.accentSecondary],
              )
            : null,
        color: isDone
            ? null
            : isActive
            ? AppTheme.accentPrimary.withValues(alpha: 0.15)
            : const Color(0x0D2060C8),
        border: Border.all(
          color: isDone
              ? Colors.transparent
              : isActive
              ? AppTheme.accentPrimary
              : AppTheme.borderDefault,
          width: isDone ? 0 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : Text(
                '${index + 1}',
                style: TextStyle(
                  color: isActive
                      ? AppTheme.accentPrimary
                      : AppTheme.textTertiary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  // ── Step content ───────────────────────────────────────────────────

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildWelcome();
      case 1:
        return _buildDependencies();
      case 2:
        return _buildPermissions();
      case 3:
        return _buildDone();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 0: Welcome ────────────────────────────────────────────────

  Widget _buildWelcome() {
    final consoleUrl = _consoleUrlForProvider(
      widget.asrProviderKey == 'local' ? 'iflytek' : widget.asrProviderKey,
    );
    final consoleHost = consoleUrl == null ? null : Uri.parse(consoleUrl).host;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEAEFF9), Color(0xFFE2E8F5)],
              ),
              border: Border.all(color: AppTheme.borderDefault, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.accentGradient.createShader(bounds),
              child: const Icon(
                Icons.mic_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text('VERBATIM', style: AppTheme.display),
          const SizedBox(height: 10),
          const Text(
            '语音转文字，一键输入到任意应用',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 6),
          const Text(
            '接下来我们将帮你完成初始设置',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          _setupChoiceCard(
            selected: _setupPreference == _SetupPreference.apiFirst,
            icon: Icons.cloud_rounded,
            title: '配置 API Key（推荐）',
            description: '无需下载本地模型，先连云端服务（建议首选讯飞）',
            onTap: () => _selectSetupPreference(_SetupPreference.apiFirst),
            badgeText: '推荐',
          ),
          const SizedBox(height: 10),
          _setupChoiceCard(
            selected: _setupPreference == _SetupPreference.localFirst,
            icon: Icons.storage_rounded,
            title: '下载本地离线模型',
            description: '先安装 SoX + Python FunASR，并下载本地模型（约 300~500 MB）',
            onTap: () => _selectSetupPreference(_SetupPreference.localFirst),
          ),
          if (_setupPreference == _SetupPreference.apiFirst &&
              consoleUrl != null &&
              consoleHost != null) ...[
            const SizedBox(height: 10),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _openExternalUrl(consoleUrl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 12,
                      color: AppTheme.accentPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '获取 API Key：$consoleHost',
                      style: const TextStyle(
                        color: AppTheme.accentPrimary,
                        fontSize: 11.5,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.accentPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            '建议先走 API 路线完成可用性，再按需补充离线模型。',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _setupChoiceCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTheme.dNormal,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x0D2060C8),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: selected
                  ? AppTheme.accentPrimary.withValues(alpha: 0.55)
                  : AppTheme.borderSubtle,
              width: selected ? 1.1 : 0.8,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.accentPrimary.withValues(alpha: 0.12),
                      blurRadius: 14,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accentPrimary.withValues(alpha: 0.18)
                      : const Color(0x0D2060C8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: selected ? AppTheme.accentPrimary : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.accentPrimary.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppTheme.accentPrimary.withValues(
                                  alpha: 0.35,
                                ),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: AppTheme.accentPrimary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected ? AppTheme.accentPrimary : AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 1: Dependencies ───────────────────────────────────────────

  Widget _buildDependencies() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('安装依赖', style: AppTheme.h2),
          const SizedBox(height: 5),
          const Text(
            '仅离线模式需要 SoX + Python FunASR；若优先用 API（推荐讯飞），可跳过本步稍后在设置中配置',
            style: AppTheme.caption,
          ),
          const SizedBox(height: 18),
          _buildModelSourceCard(),
          const SizedBox(height: 12),
          _depCard(
            icon: Icons.audiotrack_rounded,
            title: 'SoX (rec)',
            available: _soxAvailable,
            installing: _installingSox,
            log: _soxLog.toString(),
            scrollCtrl: _soxScrollCtrl,
            onInstall: _homebrewAvailable == true ? _installSox : null,
            unavailableHint: _homebrewAvailable == false
                ? '需要先安装 Homebrew (brew.sh)'
                : null,
          ),
          const SizedBox(height: 12),
          _depCard(
            icon: Icons.psychology_rounded,
            title: 'Python FunASR',
            available: _funasrAvailable,
            installing: _installingFunasr,
            log: _funasrLog.toString(),
            scrollCtrl: _funasrScrollCtrl,
            onInstall: _pythonAvailable == true ? _installFunasr : null,
            unavailableHint: _pythonAvailable == false ? '需要先安装 Python3' : null,
          ),
          const SizedBox(height: 12),
          _depCard(
            icon: Icons.download_rounded,
            title: 'ASR 模型',
            available: _modelsDownloaded,
            installing: _downloadingModels,
            log: _modelsLog.toString(),
            scrollCtrl: _modelsScrollCtrl,
            onInstall: _funasrAvailable == true ? _downloadModels : null,
            unavailableHint: _funasrAvailable == false
                ? '需要先完成 Python FunASR 安装'
                : '约 300~500 MB，慢速网络可能需要 5~15 分钟',
            installButtonLabel: '下载模型',
            progress: _downloadingModels ? _modelsDownloadProgress : null,
            progressLabel: _downloadingModels ? _modelsDownloadLabel : null,
          ),
        ],
      ),
    );
  }

  Widget _buildModelSourceCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.source_rounded,
                size: 18,
                color: AppTheme.accentPrimary,
              ),
              SizedBox(width: 10),
              Text('模型下载源', style: AppTheme.h3),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedModelSource,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              filled: true,
              fillColor: const Color(0x0D2060C8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                borderSide: const BorderSide(
                  color: AppTheme.borderDefault,
                  width: 0.8,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                borderSide: const BorderSide(
                  color: AppTheme.borderDefault,
                  width: 0.8,
                ),
              ),
            ),
            dropdownColor: const Color(0xFFE2E8F5),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5),
            items: _modelSourceOptions
                .map(
                  (item) => DropdownMenuItem(
                    value: item.key,
                    child: Text(item.label),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              final cb = widget.onModelDownloadConfigChanged;
              if (cb != null) {
                await cb(value, widget.modelDownloadMirrorUrl);
              }
            },
          ),
          if (_selectedModelSource == 'custom_hf_mirror') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _modelMirrorUrlController,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12.5,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'https://hf-mirror.com',
                hintStyle: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                filled: true,
                fillColor: const Color(0x0D2060C8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: const BorderSide(
                    color: AppTheme.borderDefault,
                    width: 0.8,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  borderSide: const BorderSide(
                    color: AppTheme.borderDefault,
                    width: 0.8,
                  ),
                ),
              ),
              onChanged: (value) async {
                final cb = widget.onModelDownloadConfigChanged;
                if (cb != null) {
                  await cb(_selectedModelSource, value.trim());
                }
              },
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _selectedModelSource == 'auto'
                ? '默认使用 ModelScope；若下载慢，可切换 HuggingFace 镜像。'
                : _selectedModelSource == 'custom_hf_mirror'
                ? '请填写可访问的镜像地址（需 http/https）。'
                : '已启用可切换下载源，可显著改善部分网络环境下的下载速度。',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _depCard({
    required IconData icon,
    required String title,
    required bool? available,
    required bool installing,
    required String log,
    required ScrollController scrollCtrl,
    required VoidCallback? onInstall,
    String? unavailableHint,
    String? installButtonLabel,
    double? progress,
    String? progressLabel,
  }) {
    final statusColor = available == true
        ? AppTheme.successGreen
        : available == false
        ? AppTheme.recordingRed
        : AppTheme.warningOrange;
    final statusLabel = available == true
        ? '已安装'
        : available == false
        ? '未安装'
        : '检测中...';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.accentGradient.createShader(bounds),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTheme.h3)),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.4),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (available == false && !installing) ...[
            const SizedBox(height: 10),
            if (unavailableHint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  unavailableHint,
                  style: const TextStyle(
                    color: AppTheme.warningOrange,
                    fontSize: 12,
                  ),
                ),
              ),
            if (onInstall != null)
              _gradientButton(installButtonLabel ?? '安装 $title', onInstall),
          ],
          if (installing || log.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 110,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0x0A000000),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
              ),
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: Text(
                  log.isEmpty ? '...' : log,
                  style: AppTheme.monoText,
                ),
              ),
            ),
            if (installing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (progress != null && progress > 0 && progress <= 1)
                        ? progress
                        : null,
                    minHeight: 2,
                    color: AppTheme.accentPrimary,
                    backgroundColor: AppTheme.borderDefault,
                  ),
                ),
              ),
            if (installing) ...[
              const SizedBox(height: 6),
              Text(
                progressLabel ?? '模型下载中，受网络影响可能较慢（建议保持网络稳定）',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── Step 2: Permissions ────────────────────────────────────────────

  Widget _buildPermissions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('授权权限', style: AppTheme.h2),
          const SizedBox(height: 5),
          const Text('应用需要麦克风和辅助功能权限才能正常工作', style: AppTheme.caption),
          const SizedBox(height: 18),
          _permCard(
            icon: Icons.mic_rounded,
            title: '麦克风权限',
            description: '用于录制语音',
            granted: _microphoneGranted,
            buttonLabel: '申请麦克风权限',
            onAction: _requestMicrophone,
          ),
          const SizedBox(height: 12),
          _permCard(
            icon: Icons.accessibility_new_rounded,
            title: '辅助功能权限',
            description: '用于自动粘贴文字到其他应用',
            granted: _accessibilityGranted,
            buttonLabel: '打开系统设置',
            onAction: _openAccessibilitySettings,
          ),
          const SizedBox(height: 14),
          const Text(
            '授权后状态会自动刷新（每 2 秒检测一次）',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _permCard({
    required IconData icon,
    required String title,
    required String description,
    required bool? granted,
    required String buttonLabel,
    required VoidCallback onAction,
  }) {
    final statusColor = granted == true
        ? AppTheme.successGreen
        : granted == false
        ? AppTheme.recordingRed
        : AppTheme.warningOrange;
    final statusLabel = granted == true
        ? '已授权'
        : granted == false
        ? '未授权'
        : '检测中...';

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.accentGradient.createShader(bounds),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.h3),
                    const SizedBox(height: 2),
                    Text(description, style: AppTheme.caption),
                  ],
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.4),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (granted != true) ...[
            const SizedBox(height: 12),
            _gradientButton(buttonLabel, onAction),
          ],
        ],
      ),
    );
  }

  // ── Step 3: Done ───────────────────────────────────────────────────

  Widget _buildDone() {
    final apiRoute = _setupPreference == _SetupPreference.apiFirst;
    final items = <_SummaryItem>[
      if (!apiRoute) ...[
        _SummaryItem('SoX (rec)', _soxAvailable == true),
        _SummaryItem('Python FunASR', _funasrAvailable == true),
        _SummaryItem('ASR 模型', _modelsDownloaded == true),
      ] else
        _SummaryItem('识别方式：云端 API（推荐）', widget.asrProviderKey != 'local'),
      _SummaryItem('麦克风权限', _microphoneGranted == true),
      _SummaryItem('辅助功能权限', _accessibilityGranted == true),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.successGreen.withValues(alpha: 0.12),
              border: Border.all(
                color: AppTheme.successGreen.withValues(alpha: 0.3),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.successGreen.withValues(alpha: 0.15),
                  blurRadius: 20,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 32,
              color: AppTheme.successGreen,
            ),
          ),
          const SizedBox(height: 18),
          const Text('设置完成', style: AppTheme.h2),
          const SizedBox(height: 18),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: Row(
                children: [
                  Icon(
                    item.ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 16,
                    color: item.ok
                        ? AppTheme.successGreen
                        : AppTheme.recordingRed,
                  ),
                  const SizedBox(width: 10),
                  Text(item.label, style: AppTheme.body),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            apiRoute
                ? '已选择 API 配置路线。建议下一步在设置页填写 API Key（可直接跳转官网获取）。'
                : '离线路线已完成。后续也可随时切回 API 模式获取更快体验。',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          if (_step == 0)
            _ghostBtn('跳过设置', widget.onSkip)
          else if (_step < 3)
            _ghostBtn('跳过', widget.onSkip),
          const Spacer(),
          if (_step == 0)
            _gradientButton(
              _setupPreference == _SetupPreference.apiFirst
                  ? '开始（API 推荐）'
                  : '开始离线配置',
              () => _goToStep(
                _setupPreference == _SetupPreference.apiFirst ? 2 : 1,
              ),
            )
          else if (_step == 1 || _step == 2)
            _gradientButton('下一步', () => _goToStep(_step + 1))
          else if (_step == 3)
            _gradientButton('开始使用', () => widget.onComplete()),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────

  Widget _gradientButton(String label, VoidCallback? onPressed) {
    return MouseRegion(
      cursor: onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            gradient: onPressed != null
                ? const LinearGradient(
                    colors: [AppTheme.accentPrimary, AppTheme.accentSecondary],
                  )
                : null,
            color: onPressed == null ? AppTheme.borderDefault : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            boxShadow: onPressed != null
                ? [
                    BoxShadow(
                      color: AppTheme.accentPrimary.withValues(alpha: 0.3),
                      blurRadius: 14,
                      spreadRadius: -3,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ghostBtn(String label, VoidCallback onPressed) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
        ),
      ),
    );
  }
}

class _SummaryItem {
  final String label;
  final bool ok;
  const _SummaryItem(this.label, this.ok);
}
