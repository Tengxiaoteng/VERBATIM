import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/asr_provider.dart';
import '../models/llm_provider.dart';
import '../models/prompt_preset.dart';
import '../services/funasr_server_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_switch.dart';
import '../widgets/hotkey_picker.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onQuit;
  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final bool? serverOnline;
  final FunasrServerStatus? serverStatus;
  final String? serverError;
  final double downloadProgress;
  final String? downloadLabel;
  final VoidCallback onRefreshServer;
  final VoidCallback? onRestartServer;
  final ValueChanged<bool>? onHotkeyListeningStateChanged;
  final bool? accessibilityGranted;
  final bool? microphoneGranted;
  final bool? recAvailable;
  final Future<void> Function()? onRefreshPermissions;
  final Future<void> Function()? onRequestAccessibilityPermission;
  final Future<void> Function()? onRequestMicrophonePermission;
  final VoidCallback? onShowHistory;

  const SettingsScreen({
    super.key,
    required this.onQuit,
    required this.settings,
    required this.onSettingsChanged,
    this.serverOnline,
    this.serverStatus,
    this.serverError,
    this.downloadProgress = 0.0,
    this.downloadLabel,
    required this.onRefreshServer,
    this.onRestartServer,
    this.onHotkeyListeningStateChanged,
    this.accessibilityGranted,
    this.microphoneGranted,
    this.recAvailable,
    this.onRefreshPermissions,
    this.onRequestAccessibilityPermission,
    this.onRequestMicrophonePermission,
    this.onShowHistory,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _asrUrlController;
  late TextEditingController _asrApiKeyController;
  late TextEditingController _asrModelController;
  late TextEditingController _asrCustomUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelTextController;
  bool _permissionBusy = false;

  @override
  void initState() {
    super.initState();
    _asrUrlController = TextEditingController(text: widget.settings.asrBaseUrl);
    _asrApiKeyController = TextEditingController(text: widget.settings.asrApiKey);
    _asrModelController = TextEditingController(text: widget.settings.asrModel);
    _asrCustomUrlController = TextEditingController(text: widget.settings.asrCustomUrl);
    _apiKeyController = TextEditingController(text: widget.settings.llmApiKey);
    _baseUrlController = TextEditingController(text: widget.settings.llmBaseUrl);
    _modelTextController = TextEditingController(text: widget.settings.llmModel);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.asrBaseUrl != widget.settings.asrBaseUrl) {
      _asrUrlController.text = widget.settings.asrBaseUrl;
    }
    if (oldWidget.settings.asrApiKey != widget.settings.asrApiKey) {
      _asrApiKeyController.text = widget.settings.asrApiKey;
    }
    if (oldWidget.settings.asrModel != widget.settings.asrModel) {
      _asrModelController.text = widget.settings.asrModel;
    }
    if (oldWidget.settings.asrCustomUrl != widget.settings.asrCustomUrl) {
      _asrCustomUrlController.text = widget.settings.asrCustomUrl;
    }
    if (oldWidget.settings.llmApiKey != widget.settings.llmApiKey) {
      _apiKeyController.text = widget.settings.llmApiKey;
    }
    if (oldWidget.settings.llmBaseUrl != widget.settings.llmBaseUrl) {
      _baseUrlController.text = widget.settings.llmBaseUrl;
    }
    if (oldWidget.settings.llmModel != widget.settings.llmModel) {
      _modelTextController.text = widget.settings.llmModel;
    }
  }

  @override
  void dispose() {
    _asrUrlController.dispose();
    _asrApiKeyController.dispose();
    _asrModelController.dispose();
    _asrCustomUrlController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelTextController.dispose();
    super.dispose();
  }

  AppSettings get _s => widget.settings;
  void _update(AppSettings updated) => widget.onSettingsChanged(updated);
  bool get _isLocalAsr => _s.asrProviderKey == 'local';
  LlmProvider? get _currentProvider => LlmProvider.findByKey(_s.llmProviderKey);
  List<PromptPreset> get _allPrompts => [
        ...PromptPreset.defaults,
        ..._s.customPrompts,
      ];
  PromptPreset? get _activePreset {
    for (final p in _allPrompts) {
      if (p.id == _s.activePromptId) return p;
    }
    return PromptPreset.defaults.first;
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: _buildPanel(),
    );
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppTheme.borderDefault,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(
                          _isLocalAsr ? '服务状态' : '语音识别引擎',
                        ),
                        const SizedBox(height: 8),
                        _buildServerStatus(),
                        const SizedBox(height: 20),
                        _buildSectionLabel('快捷键'),
                        const SizedBox(height: 8),
                        _buildHotkeySection(),
                        const SizedBox(height: 20),
                        _buildSectionLabel('AI 后处理'),
                        const SizedBox(height: 8),
                        _buildLlmSection(),
                        const SizedBox(height: 20),
                        _buildSectionLabel('提示词'),
                        const SizedBox(height: 8),
                        _buildPromptSection(),
                        const SizedBox(height: 20),
                        _buildPermissionNote(),
                        const SizedBox(height: 24),
                        _buildQuitButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.accentGradient.createShader(bounds),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'VERBATIM',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w300,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          if (widget.onShowHistory != null)
            _headerIconBtn(
              icon: Icons.history_rounded,
              tooltip: '历史记录',
              onPressed: widget.onShowHistory!,
            ),
          const SizedBox(width: 8),
          const Text(
            'v2.1',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerIconBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0x0D2060C8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
            ),
            child: Icon(icon, size: 14, color: AppTheme.textTertiary),
          ),
        ),
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(text.toUpperCase(), style: AppTheme.sectionLabel),
    );
  }

  // ── Server status / ASR provider ───────────────────────────────────

  Widget _buildServerStatus() {
    final status = widget.serverStatus;

    // Compute local status indicators only when needed
    Color dotColor = AppTheme.textMuted;
    String statusLabel = '';
    bool showSpinner = false;
    bool showRestartButton = false;

    if (_isLocalAsr) {
      switch (status) {
        case FunasrServerStatus.starting:
          dotColor = AppTheme.warningOrange;
          statusLabel = 'FunASR 启动中...';
          showSpinner = true;
          showRestartButton = false;
          break;
        case FunasrServerStatus.loadingModels:
          dotColor = AppTheme.warningOrange;
          statusLabel = '加载模型中...';
          showSpinner = true;
          showRestartButton = false;
          break;
        case FunasrServerStatus.ready:
          dotColor = AppTheme.successGreen;
          statusLabel = 'FunASR 在线';
          showSpinner = false;
          showRestartButton = false;
          break;
        case FunasrServerStatus.error:
          dotColor = AppTheme.recordingRed;
          statusLabel = widget.serverError ?? 'FunASR 错误';
          showSpinner = false;
          showRestartButton = true;
          break;
        case FunasrServerStatus.stopped:
        case null:
          if (widget.serverOnline == null) {
            dotColor = AppTheme.warningOrange;
            statusLabel = 'FunASR 检测中...';
            showSpinner = false;
            showRestartButton = false;
          } else if (widget.serverOnline!) {
            dotColor = AppTheme.successGreen;
            statusLabel = 'FunASR 在线';
            showSpinner = false;
            showRestartButton = false;
          } else {
            dotColor = AppTheme.textMuted;
            statusLabel = 'FunASR 已停止';
            showSpinner = false;
            showRestartButton = true;
          }
          break;
      }
    }

    final isDownloading = _isLocalAsr &&
        widget.downloadProgress > 0 &&
        (status == FunasrServerStatus.starting ||
            status == FunasrServerStatus.loadingModels);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Provider dropdown — always at the top
          _fieldLabel('服务商', enabled: true),
          const SizedBox(height: 4),
          _asrProviderDropdown(),

          if (_isLocalAsr) ...[
            // ── Local FunASR UI ──────────────────────────────────────
            const SizedBox(height: 10),
            Row(
              children: [
                if (showSpinner)
                  const SizedBox(
                    width: 11,
                    height: 11,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.warningOrange,
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                      boxShadow: [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showRestartButton && widget.onRestartServer != null)
                  _accentTextBtn('重启', widget.onRestartServer),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onRefreshServer,
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 15,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (isDownloading) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 0.5, color: AppTheme.borderSubtle),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.download_rounded, size: 13, color: AppTheme.warningOrange),
                  const SizedBox(width: 6),
                  const Text(
                    '首次使用需下载语音识别模型（约 1 GB）',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(widget.downloadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: AppTheme.warningOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: widget.downloadProgress,
                  minHeight: 3,
                  backgroundColor: AppTheme.borderDefault,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warningOrange),
                ),
              ),
              if (widget.downloadLabel != null) ...[
                const SizedBox(height: 5),
                Text(
                  widget.downloadLabel!,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            const Divider(
              height: 1,
              thickness: 0.5,
              color: AppTheme.borderSubtle,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '自动启动服务器',
                    style: TextStyle(
                      color: _s.autoStartServer
                          ? AppTheme.textPrimary
                          : AppTheme.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ),
                GlassSwitch(
                  value: _s.autoStartServer,
                  onChanged: (v) => _update(_s.copyWith(autoStartServer: v)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _fieldLabel('ASR 服务器地址', enabled: true),
            const SizedBox(height: 4),
            _textField(
              controller: _asrUrlController,
              enabled: true,
              hint: 'http://localhost:10095',
              onChanged: (v) => _update(_s.copyWith(asrBaseUrl: v)),
            ),
          ] else ...[
            // ── Cloud ASR UI ─────────────────────────────────────────
            const SizedBox(height: 10),
            _fieldLabel(
              _s.asrProviderKey == 'iflytek'
                  ? 'AppID:APIKey:APISecret'
                  : 'API Key',
              enabled: true,
            ),
            const SizedBox(height: 4),
            _textField(
              controller: _asrApiKeyController,
              enabled: true,
              obscureText: true,
              hint: _s.asrProviderKey == 'iflytek'
                  ? 'f12f0d90:c5fa7d39...:Nzc2Mjhm...'
                  : '输入 API Key',
              onChanged: (v) => _update(_s.copyWith(asrApiKey: v)),
            ),
            const SizedBox(height: 10),
            _fieldLabel(
              _s.asrProviderKey == 'iflytek' ? '语言' : '模型',
              enabled: true,
            ),
            const SizedBox(height: 4),
            _textField(
              controller: _asrModelController,
              enabled: true,
              hint: _s.asrProviderKey == 'iflytek'
                  ? 'zh_cn（默认）或 en_us'
                  : '输入模型名称',
              onChanged: (v) => _update(_s.copyWith(asrModel: v)),
            ),
            if (_s.asrProviderKey == 'custom') ...[
              const SizedBox(height: 10),
              _fieldLabel('Endpoint URL', enabled: true),
              const SizedBox(height: 4),
              _textField(
                controller: _asrCustomUrlController,
                enabled: true,
                hint: 'https://api.example.com/v1/audio/transcriptions',
                onChanged: (v) => _update(_s.copyWith(asrCustomUrl: v)),
              ),
            ],
            const SizedBox(height: 8),
            _asrInfoHint(),
          ],
        ],
      ),
    );
  }

  Widget _asrProviderDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _s.asrProviderKey,
      decoration: _dropdownDecoration(true),
      dropdownColor: const Color(0xFFE2E8F5),
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 13,
      ),
      iconEnabledColor: AppTheme.textTertiary,
      items: AsrProvider.builtIn.map((p) {
        return DropdownMenuItem(value: p.key, child: Text(p.name));
      }).toList(),
      onChanged: (key) {
        if (key == null) return;
        final provider = AsrProvider.findByKey(key);
        if (provider == null) return;
        _asrModelController.text = provider.defaultModel;
        _update(_s.copyWith(
          asrProviderKey: key,
          asrModel: provider.defaultModel,
        ));
      },
    );
  }

  Widget _asrInfoHint() {
    final key = _s.asrProviderKey;
    final String hint;
    switch (key) {
      case 'openai':
        hint = '在 platform.openai.com 注册获取 API Key';
        break;
      case 'groq':
        hint = '在 console.groq.com 注册获取免费 API Key';
        break;
      case 'siliconflow':
        hint = '在 siliconflow.cn 注册获取免费 API Key';
        break;
      case 'iflytek':
        hint = '在 console.xfyun.cn 创建应用，填入 AppID:APIKey:APISecret';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Row(
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 12,
          color: AppTheme.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            hint,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }

  // ── Hotkey ─────────────────────────────────────────────────────────

  Widget _buildHotkeySection() {
    return _card(
      child: HotkeyPicker(
        currentKey: _s.hotkeyKey,
        currentModifiers: _s.hotkeyModifiers,
        onHotkeyChanged: (key, modifiers) {
          _update(_s.copyWith(hotkeyKey: key, hotkeyModifiers: modifiers));
        },
        onListeningStateChanged: widget.onHotkeyListeningStateChanged,
      ),
    );
  }

  // ── LLM section ────────────────────────────────────────────────────

  Widget _buildLlmSection() {
    final enabled = _s.llmEnabled;
    final provider = _currentProvider;
    final isCustom = _s.llmProviderKey == 'custom';
    final hasModels = provider != null && provider.models.isNotEmpty;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '启用 LLM 后处理',
                  style: TextStyle(
                    color: enabled
                        ? AppTheme.textPrimary
                        : AppTheme.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              GlassSwitch(
                value: enabled,
                onChanged: (v) => _update(_s.copyWith(llmEnabled: v)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel('服务商', enabled: enabled),
          const SizedBox(height: 4),
          _providerDropdown(enabled),
          const SizedBox(height: 10),
          _fieldLabel('API Key', enabled: enabled),
          const SizedBox(height: 4),
          _textField(
            controller: _apiKeyController,
            enabled: enabled,
            obscureText: true,
            hint: '输入 API Key',
            onChanged: (v) => _update(_s.copyWith(llmApiKey: v)),
          ),
          if (isCustom) ...[
            const SizedBox(height: 10),
            _fieldLabel('Base URL', enabled: enabled),
            const SizedBox(height: 4),
            _textField(
              controller: _baseUrlController,
              enabled: enabled,
              hint: 'https://api.example.com/v1',
              onChanged: (v) => _update(_s.copyWith(llmBaseUrl: v)),
            ),
          ],
          const SizedBox(height: 10),
          _fieldLabel('模型', enabled: enabled),
          const SizedBox(height: 4),
          if (hasModels)
            _modelDropdown(provider, enabled)
          else
            _textField(
              controller: _modelTextController,
              enabled: enabled,
              hint: '输入模型名称',
              onChanged: (v) => _update(_s.copyWith(llmModel: v)),
            ),
        ],
      ),
    );
  }

  Widget _providerDropdown(bool enabled) {
    return DropdownButtonFormField<String>(
      initialValue: _s.llmProviderKey,
      decoration: _dropdownDecoration(enabled),
      dropdownColor: const Color(0xFFE2E8F5),
      style: TextStyle(
        color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
        fontSize: 13,
      ),
      iconEnabledColor: AppTheme.textTertiary,
      iconDisabledColor: AppTheme.textMuted,
      items: LlmProvider.builtIn.map((p) {
        return DropdownMenuItem(value: p.key, child: Text(p.name));
      }).toList(),
      onChanged: enabled
          ? (key) {
              if (key == null) return;
              final provider = LlmProvider.findByKey(key);
              if (provider == null) return;
              final newModel =
                  provider.models.isNotEmpty ? provider.models.first : '';
              final newBaseUrl =
                  key == 'custom' ? _s.llmBaseUrl : provider.baseUrl;
              _baseUrlController.text = newBaseUrl;
              _modelTextController.text = newModel;
              _update(_s.copyWith(
                llmProviderKey: key,
                llmBaseUrl: newBaseUrl,
                llmModel: newModel,
              ));
            }
          : null,
    );
  }

  Widget _modelDropdown(LlmProvider provider, bool enabled) {
    final currentModel = provider.models.contains(_s.llmModel)
        ? _s.llmModel
        : provider.models.first;

    return DropdownButtonFormField<String>(
      initialValue: currentModel,
      decoration: _dropdownDecoration(enabled),
      dropdownColor: const Color(0xFFE2E8F5),
      style: TextStyle(
        color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
        fontSize: 13,
      ),
      iconEnabledColor: AppTheme.textTertiary,
      iconDisabledColor: AppTheme.textMuted,
      items: provider.models.map((m) {
        return DropdownMenuItem(value: m, child: Text(m));
      }).toList(),
      onChanged: enabled
          ? (m) {
              if (m != null) _update(_s.copyWith(llmModel: m));
            }
          : null,
    );
  }

  InputDecoration _dropdownDecoration(bool enabled) {
    return InputDecoration(
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: enabled
          ? const Color(0x0D2060C8)
          : const Color(0x06000000),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: const BorderSide(color: AppTheme.borderDefault, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: const BorderSide(color: AppTheme.borderDefault, width: 0.8),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: const BorderSide(
          color: AppTheme.borderSubtle,
          width: 0.8,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, {required bool enabled}) {
    return Text(
      text,
      style: TextStyle(
        color: enabled ? AppTheme.textTertiary : AppTheme.textMuted,
        fontSize: 11.5,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required bool enabled,
    required String hint,
    bool obscureText = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      style: TextStyle(
        color: enabled ? AppTheme.textPrimary : AppTheme.textMuted,
        fontSize: 13,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        hintText: hint,
        hintStyle: TextStyle(
          color: enabled ? AppTheme.textMuted : const Color(0x1AFFFFFF),
          fontSize: 13,
        ),
        filled: true,
        fillColor: enabled
            ? const Color(0x0D2060C8)
            : const Color(0x06000000),
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
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          borderSide: const BorderSide(
            color: AppTheme.accentPrimary,
            width: 1.0,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          borderSide: const BorderSide(
            color: AppTheme.borderSubtle,
            width: 0.8,
          ),
        ),
      ),
      onChanged: onChanged,
    );
  }

  // ── Prompt section ─────────────────────────────────────────────────

  Widget _buildPromptSection() {
    final prompts = _allPrompts;
    final active = _activePreset;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ...prompts.map((p) => _promptChip(p, p.id == _s.activePromptId)),
              ActionChip(
                label: const Text(
                  '+ 自定义',
                  style: TextStyle(
                    color: AppTheme.accentPrimary,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: const Color(0x0D2060C8),
                side: const BorderSide(
                  color: AppTheme.borderSubtle,
                  width: 0.8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: _showAddPresetDialog,
              ),
            ],
          ),
          if (active != null && active.systemPrompt.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x08FFFFFF),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(
                  color: AppTheme.borderSubtle,
                  width: 0.8,
                ),
              ),
              child: Text(
                active.systemPrompt,
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11.5,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _promptChip(PromptPreset preset, bool selected) {
    return InputChip(
      label: Text(
        preset.name,
        style: TextStyle(
          color: selected ? Colors.white : AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: AppTheme.accentPrimary.withValues(alpha: 0.28),
      backgroundColor: const Color(0x0D2060C8),
      side: BorderSide(
        color: selected
            ? AppTheme.accentPrimary.withValues(alpha: 0.45)
            : AppTheme.borderSubtle,
        width: 0.8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) => _update(_s.copyWith(activePromptId: preset.id)),
      onDeleted: preset.builtIn ? null : () => _showDeletePresetDialog(preset),
      deleteIcon: preset.builtIn
          ? null
          : const Icon(Icons.close_rounded, size: 13),
      deleteIconColor: AppTheme.textTertiary,
    );
  }

  // ── Add / delete prompt dialogs ────────────────────────────────────

  void _showAddPresetDialog() {
    final nameCtrl = TextEditingController();
    final promptCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE2E8F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          side: const BorderSide(color: AppTheme.borderDefault, width: 0.8),
        ),
        title: const Text(
          '添加自定义提示词',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogTextField(nameCtrl, '名称'),
            const SizedBox(height: 10),
            _dialogTextField(promptCtrl, 'System prompt', maxLines: 4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final prompt = promptCtrl.text.trim();
              if (name.isEmpty) return;
              final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
              final preset = PromptPreset(
                id: id,
                name: name,
                systemPrompt: prompt,
              );
              final updated = _s.copyWith(
                customPrompts: [..._s.customPrompts, preset],
                activePromptId: id,
              );
              _update(updated);
              Navigator.pop(ctx);
            },
            child: const Text(
              '添加',
              style: TextStyle(color: AppTheme.accentPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeletePresetDialog(PromptPreset preset) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFE2E8F5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          side: const BorderSide(color: AppTheme.borderDefault, width: 0.8),
        ),
        title: const Text(
          '删除提示词',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          '确定删除「${preset.name}」？',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              '取消',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () {
              final newCustom =
                  _s.customPrompts.where((p) => p.id != preset.id).toList();
              final newActiveId =
                  _s.activePromptId == preset.id ? 'direct' : _s.activePromptId;
              _update(_s.copyWith(
                customPrompts: newCustom,
                activePromptId: newActiveId,
              ));
              Navigator.pop(ctx);
            },
            child: const Text(
              '删除',
              style: TextStyle(color: AppTheme.recordingRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogTextField(
    TextEditingController ctrl,
    String hint, {
    int? maxLines,
  }) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        filled: true,
        fillColor: const Color(0x0D2060C8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          borderSide: const BorderSide(color: AppTheme.borderDefault, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          borderSide: const BorderSide(color: AppTheme.borderDefault, width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          borderSide: const BorderSide(color: AppTheme.accentPrimary, width: 1.0),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  // ── Permission note ────────────────────────────────────────────────

  Widget _buildPermissionNote() {
    final recOk = widget.recAvailable;
    final micOk = widget.microphoneGranted;
    final a11yOk = widget.accessibilityGranted;

    String statusLabel(bool? ok) {
      if (ok == true) return '已授权';
      if (ok == false) return '未授权';
      return '检测中';
    }

    Color statusColor(bool? ok) {
      if (ok == true) return AppTheme.successGreen;
      if (ok == false) return AppTheme.recordingRed;
      return AppTheme.warningOrange;
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFF39C12), Color(0xFFE67E22)],
                ).createShader(bounds),
                child: const Icon(
                  Icons.security_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '权限体检',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            thickness: 0.5,
            color: AppTheme.borderSubtle,
          ),
          const SizedBox(height: 10),
          _permissionLine(
            label: 'SoX/rec 命令',
            status: statusLabel(recOk),
            color: statusColor(recOk),
          ),
          const SizedBox(height: 7),
          _permissionLine(
            label: '麦克风权限',
            status: statusLabel(micOk),
            color: statusColor(micOk),
          ),
          const SizedBox(height: 7),
          _permissionLine(
            label: '辅助功能权限',
            status: statusLabel(a11yOk),
            color: statusColor(a11yOk),
          ),
          const SizedBox(height: 10),
          Text(
            '建议按顺序完成：1) 安装 SoX  2) 麦克风授权  3) 辅助功能授权',
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (a11yOk == false) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
              ),
              child: const Text(
                '① 点击下方「触发权限申请」\n'
                '② 弹出对话框后点击「打开系统设置」\n'
                '③ 在列表中找到 VERBATIM，打开右侧开关',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  height: 1.7,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _permissionButton(
                label: '刷新权限',
                onPressed: widget.onRefreshPermissions,
              ),
              _permissionButton(
                label: '申请麦克风权限',
                onPressed: widget.onRequestMicrophonePermission,
              ),
              _permissionButton(
                label: a11yOk == true ? '辅助功能已授权' : '触发权限申请',
                onPressed: a11yOk == true
                    ? null
                    : widget.onRequestAccessibilityPermission,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _permissionLine({
    required String label,
    required String status,
    required Color color,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _permissionButton({
    required String label,
    required Future<void> Function()? onPressed,
  }) {
    return MouseRegion(
      cursor: (_permissionBusy || onPressed == null)
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _permissionBusy || onPressed == null
            ? null
            : () async {
                setState(() => _permissionBusy = true);
                try {
                  await onPressed();
                } finally {
                  if (mounted) setState(() => _permissionBusy = false);
                }
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0x0D2060C8),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(
              color: AppTheme.borderDefault,
              width: 0.8,
            ),
          ),
          child: Text(
            _permissionBusy ? '处理中...' : label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ── Quit button ────────────────────────────────────────────────────

  Widget _buildQuitButton() {
    return Center(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onQuit,
          child: const Text(
            '退出 VERBATIM',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return GlassCard(child: child);
  }

  Widget _accentTextBtn(String label, VoidCallback? onPressed) {
    return MouseRegion(
      cursor:
          onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accentPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppTheme.accentPrimary.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.accentPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
