import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/install_service.dart';
import '../services/paste_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SetupWizardScreen extends StatefulWidget {
  final PasteService pasteService;
  final InstallService installService;
  final Future<void> Function() onComplete;
  final VoidCallback onSkip;

  const SetupWizardScreen({
    super.key,
    required this.pasteService,
    required this.installService,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;

  // ── Step 1: Dependencies ──
  bool? _soxAvailable;
  bool? _funasrAvailable;
  bool? _homebrewAvailable;
  bool? _pythonAvailable;
  bool? _modelsDownloaded;
  bool _installingSox = false;
  bool _installingFunasr = false;
  bool _downloadingModels = false;
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

  @override
  void dispose() {
    _permissionPollTimer?.cancel();
    _soxScrollCtrl.dispose();
    _funasrScrollCtrl.dispose();
    _modelsScrollCtrl.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    if (step == 1) _checkDependencies();
    if (step == 2) _startPermissionPolling();
    if (step != 2) _permissionPollTimer?.cancel();
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
    });
    final success = await widget.installService.downloadModels(
      onOutput: (line) {
        if (!mounted) return;
        setState(() => _modelsLog.write(line));
        _scrollToBottom(_modelsScrollCtrl);
      },
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
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderDefault, width: 0.8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15.2),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
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
                colors: [
                  Color(0xFFEAEFF9),
                  Color(0xFFE2E8F5),
                ],
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
          Text(
            '语音转文字，一键输入到任意应用',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '接下来我们将帮你完成初始设置',
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12.5,
            ),
          ),
        ],
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
            '应用需要 SoX（录音）和 Python FunASR（语音识别）',
            style: AppTheme.caption,
          ),
          const SizedBox(height: 18),
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
            unavailableHint:
                _pythonAvailable == false ? '需要先安装 Python3' : null,
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
                : '约 300~500 MB，首次需要下载',
            installButtonLabel: '下载模型',
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
              Expanded(
                child: Text(title, style: AppTheme.h3),
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
            if (onInstall != null) _gradientButton(installButtonLabel ?? '安装 $title', onInstall),
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
                  child: const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppTheme.accentPrimary,
                    backgroundColor: AppTheme.borderDefault,
                  ),
                ),
              ),
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
          const Text(
            '应用需要麦克风和辅助功能权限才能正常工作',
            style: AppTheme.caption,
          ),
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
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11.5,
            ),
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
    final items = <_SummaryItem>[
      _SummaryItem('SoX (rec)', _soxAvailable == true),
      _SummaryItem('Python FunASR', _funasrAvailable == true),
      _SummaryItem('ASR 模型', _modelsDownloaded == true),
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
                    item.ok
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
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
          const Text(
            '未完成的项目可稍后在设置中配置',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11.5,
            ),
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
            _gradientButton('开始设置', () => _goToStep(1))
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
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 12.5,
          ),
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
