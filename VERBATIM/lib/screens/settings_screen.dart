import 'dart:io';
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
  late TextEditingController _iflytekAppIdController;
  late TextEditingController _iflytekApiKeyController;
  late TextEditingController _iflytekApiSecretController;
  late TextEditingController _asrModelController;
  late TextEditingController _asrCustomUrlController;
  late TextEditingController _modelDownloadMirrorUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;
  late TextEditingController _modelTextController;
  bool _permissionBusy = false;
  bool _syncingIflytekFields = false;

  static const List<({String key, String label})> _modelSourceOptions = [
    (key: 'auto', label: 'ModelScope 默认源'),
    (key: 'hf_official', label: 'HuggingFace 官方'),
    (key: 'hf_mirror', label: 'HuggingFace 镜像（推荐）'),
    (key: 'custom_hf_mirror', label: '自定义 HuggingFace 镜像'),
  ];

  @override
  void initState() {
    super.initState();
    _asrUrlController = TextEditingController(text: widget.settings.asrBaseUrl);
    _asrApiKeyController = TextEditingController(
      text: widget.settings.asrApiKey,
    );
    _iflytekAppIdController = TextEditingController();
    _iflytekApiKeyController = TextEditingController();
    _iflytekApiSecretController = TextEditingController();
    _syncIflytekFieldsFromCombined(widget.settings.asrApiKey);
    _asrModelController = TextEditingController(text: widget.settings.asrModel);
    _asrCustomUrlController = TextEditingController(
      text: widget.settings.asrCustomUrl,
    );
    _modelDownloadMirrorUrlController = TextEditingController(
      text: widget.settings.modelDownloadMirrorUrl,
    );
    _apiKeyController = TextEditingController(text: widget.settings.llmApiKey);
    _baseUrlController = TextEditingController(
      text: widget.settings.llmBaseUrl,
    );
    _modelTextController = TextEditingController(
      text: widget.settings.llmModel,
    );
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.asrBaseUrl != widget.settings.asrBaseUrl) {
      _asrUrlController.text = widget.settings.asrBaseUrl;
    }
    if (oldWidget.settings.asrApiKey != widget.settings.asrApiKey) {
      _asrApiKeyController.text = widget.settings.asrApiKey;
      _syncIflytekFieldsFromCombined(widget.settings.asrApiKey);
    }
    if (oldWidget.settings.asrModel != widget.settings.asrModel) {
      _asrModelController.text = widget.settings.asrModel;
    }
    if (oldWidget.settings.asrCustomUrl != widget.settings.asrCustomUrl) {
      _asrCustomUrlController.text = widget.settings.asrCustomUrl;
    }
    if (oldWidget.settings.modelDownloadMirrorUrl !=
        widget.settings.modelDownloadMirrorUrl) {
      _modelDownloadMirrorUrlController.text =
          widget.settings.modelDownloadMirrorUrl;
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
    _iflytekAppIdController.dispose();
    _iflytekApiKeyController.dispose();
    _iflytekApiSecretController.dispose();
    _asrModelController.dispose();
    _asrCustomUrlController.dispose();
    _modelDownloadMirrorUrlController.dispose();
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
                      _buildSectionLabel(_isLocalAsr ? '服务状态' : '语音识别引擎'),
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
                      _buildSectionLabel('输出预览'),
                      const SizedBox(height: 8),
                      _buildOutputPreviewSection(),
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
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
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

    final isDownloading =
        _isLocalAsr &&
        widget.downloadProgress > 0 &&
        (status == FunasrServerStatus.starting ||
            status == FunasrServerStatus.loadingModels);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Provider dropdown — always at the top
          _asrStrategyHint(),
          const SizedBox(height: 10),
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
              const Divider(
                height: 1,
                thickness: 0.5,
                color: AppTheme.borderSubtle,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.download_rounded,
                    size: 13,
                    color: AppTheme.warningOrange,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '首次使用需下载语音识别模型（约 300~500 MB）',
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
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.warningOrange,
                  ),
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
              ] else ...[
                const SizedBox(height: 5),
                const Text(
                  '下载速度受网络影响，慢速网络下可能需要几分钟',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
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
            const SizedBox(height: 10),
            _fieldLabel('模型下载源', enabled: true),
            const SizedBox(height: 4),
            _modelSourceDropdown(),
            if (_s.modelDownloadSource == 'custom_hf_mirror') ...[
              const SizedBox(height: 8),
              _fieldLabel('自定义镜像 URL', enabled: true),
              const SizedBox(height: 4),
              _textField(
                controller: _modelDownloadMirrorUrlController,
                enabled: true,
                hint: 'https://hf-mirror.com',
                onChanged: (v) =>
                    _update(_s.copyWith(modelDownloadMirrorUrl: v.trim())),
              ),
            ],
            const SizedBox(height: 6),
            const Text(
              '下载慢时可切换到 HuggingFace 镜像；该设置会影响向导下载和服务器自动拉取模型。',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
            ),
          ] else ...[
            // ── Cloud ASR UI ─────────────────────────────────────────
            const SizedBox(height: 10),
            if (_s.asrProviderKey == 'iflytek')
              _buildIflytekCredentialFields()
            else ...[
              _fieldLabel('API Key', enabled: true),
              const SizedBox(height: 4),
              _textField(
                controller: _asrApiKeyController,
                enabled: true,
                obscureText: true,
                hint: '输入 API Key',
                onChanged: (v) => _update(_s.copyWith(asrApiKey: v)),
              ),
            ],
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
            const SizedBox(height: 4),
            _asrApiKeyLink(),
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
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      iconEnabledColor: AppTheme.textTertiary,
      items: AsrProvider.builtIn.map((p) {
        return DropdownMenuItem(
          value: p.key,
          child: Text(_asrProviderDisplayName(p)),
        );
      }).toList(),
      onChanged: (key) {
        if (key == null) return;
        final provider = AsrProvider.findByKey(key);
        if (provider == null) return;
        _asrModelController.text = provider.defaultModel;
        _update(
          _s.copyWith(asrProviderKey: key, asrModel: provider.defaultModel),
        );
      },
    );
  }

  Widget _modelSourceDropdown() {
    final current =
        _modelSourceOptions.any((o) => o.key == _s.modelDownloadSource)
        ? _s.modelDownloadSource
        : 'auto';
    return DropdownButtonFormField<String>(
      initialValue: current,
      decoration: _dropdownDecoration(true),
      dropdownColor: const Color(0xFFE2E8F5),
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      iconEnabledColor: AppTheme.textTertiary,
      items: _modelSourceOptions
          .map(
            (item) =>
                DropdownMenuItem(value: item.key, child: Text(item.label)),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        _update(_s.copyWith(modelDownloadSource: value));
      },
    );
  }

  String _asrProviderDisplayName(AsrProvider provider) {
    final site = _asrProviderApiSite(provider.key);
    if (site == null) return provider.name;
    return '${provider.name} · $site';
  }

  String? _asrProviderApiSite(String key) {
    switch (key) {
      case 'iflytek':
        return 'console.xfyun.cn';
      case 'siliconflow':
        return 'siliconflow.cn';
      case 'openai':
        return 'platform.openai.com';
      case 'groq':
        return 'console.groq.com';
      default:
        return null;
    }
  }

  String? _asrProviderApiUrl(String key) {
    switch (key) {
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

  List<String>? _parseIflytekCredential(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 3) return null;
    return parts.map((p) => p.trim()).toList();
  }

  void _syncIflytekFieldsFromCombined(String combined) {
    final parts = _parseIflytekCredential(combined) ?? ['', '', ''];
    _syncingIflytekFields = true;
    _iflytekAppIdController.text = parts[0];
    _iflytekApiKeyController.text = parts[1];
    _iflytekApiSecretController.text = parts[2];
    _syncingIflytekFields = false;
  }

  String _composeIflytekCredential() {
    final appId = _iflytekAppIdController.text.trim();
    final apiKey = _iflytekApiKeyController.text.trim();
    final apiSecret = _iflytekApiSecretController.text.trim();
    if (appId.isEmpty && apiKey.isEmpty && apiSecret.isEmpty) {
      return '';
    }
    return '$appId:$apiKey:$apiSecret';
  }

  void _onIflytekFieldChanged(String value) {
    if (_syncingIflytekFields) return;

    final parsed = _parseIflytekCredential(value);
    if (parsed != null) {
      _syncingIflytekFields = true;
      _iflytekAppIdController.text = parsed[0];
      _iflytekApiKeyController.text = parsed[1];
      _iflytekApiSecretController.text = parsed[2];
      _syncingIflytekFields = false;
      _update(_s.copyWith(asrApiKey: parsed.join(':')));
      return;
    }

    _update(_s.copyWith(asrApiKey: _composeIflytekCredential()));
  }

  Widget _asrInfoHint() {
    final key = _s.asrProviderKey;
    final String hint;
    switch (key) {
      case 'local':
        hint = '离线可用：需安装 Python FunASR 并下载本地模型（约 300~500 MB）';
        break;
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
        hint = '推荐优先使用：在 console.xfyun.cn 创建应用，填入 AppID:APIKey:APISecret';
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
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
        ),
      ],
    );
  }

  Widget _buildIflytekCredentialFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('APPID', enabled: true),
        const SizedBox(height: 4),
        _textField(
          controller: _iflytekAppIdController,
          enabled: true,
          hint: '例如：ee8e8087',
          onChanged: _onIflytekFieldChanged,
        ),
        const SizedBox(height: 8),
        _fieldLabel('APIKey', enabled: true),
        const SizedBox(height: 4),
        _textField(
          controller: _iflytekApiKeyController,
          enabled: true,
          hint: '例如：929fbe48b0d8c14cea0daadd29e8ed02',
          onChanged: _onIflytekFieldChanged,
        ),
        const SizedBox(height: 8),
        _fieldLabel('APISecret', enabled: true),
        const SizedBox(height: 4),
        _textField(
          controller: _iflytekApiSecretController,
          enabled: true,
          obscureText: true,
          hint: '输入 APISecret',
          onChanged: _onIflytekFieldChanged,
        ),
        const SizedBox(height: 6),
        const Text(
          '可把“APPID:APIKey:APISecret”整串粘贴到任意输入框，会自动拆分。',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
        ),
      ],
    );
  }

  Future<void> _openExternalUrl(String url) async {
    try {
      final result = await Process.run('open', [url]);
      if (result.exitCode != 0) {
        debugPrint('[Settings] open url failed: ${result.stderr}');
      }
    } catch (e) {
      debugPrint('[Settings] open url exception: $e');
    }
  }

  Widget _asrApiKeyLink() {
    final url = _asrProviderApiUrl(_s.asrProviderKey);
    if (url == null) return const SizedBox.shrink();
    final host = Uri.parse(url).host;

    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _openExternalUrl(url),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 12,
                  color: AppTheme.accentPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  '获取 API Key：$host',
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
      ),
    );
  }

  Widget _asrStrategyHint() {
    return Row(
      children: const [
        Icon(Icons.recommend_rounded, size: 12, color: AppTheme.textMuted),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            '推荐顺序：API 配置（首推讯飞）→ 其他云端服务 → 本地 FunASR（离线备选）',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
        ),
      ],
    );
  }

  // ── Hotkey ─────────────────────────────────────────────────────────

  Widget _buildHotkeySection() {
    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '录音热键（按下开始，松开结束）',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              HotkeyPicker(
                currentKey: _s.hotkeyKey,
                currentModifiers: _s.hotkeyModifiers,
                description: '按住快捷键开始录音',
                onHotkeyChanged: (key, modifiers) {
                  _update(
                    _s.copyWith(hotkeyKey: key, hotkeyModifiers: modifiers),
                  );
                },
                onListeningStateChanged: widget.onHotkeyListeningStateChanged,
              ),
              const SizedBox(height: 8),
              const Text(
                '推荐直接使用 Fn，支持纯单键触发。',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '模式切换热键（按住触发一次）',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              HotkeyPicker(
                currentKey: _s.modeSwitchHotkeyKey,
                currentModifiers: _s.modeSwitchHotkeyModifiers,
                description: '按住快捷键切换模式',
                onHotkeyChanged: (key, modifiers) {
                  _update(
                    _s.copyWith(
                      modeSwitchHotkeyKey: key,
                      modeSwitchHotkeyModifiers: modifiers,
                    ),
                  );
                },
                onListeningStateChanged: widget.onHotkeyListeningStateChanged,
              ),
              const SizedBox(height: 8),
              const Text(
                '用于在 直接输出 / 逻辑优化 / Code 模式 间快速切换。',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
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
              final newModel = provider.models.isNotEmpty
                  ? provider.models.first
                  : '';
              final newBaseUrl = key == 'custom'
                  ? _s.llmBaseUrl
                  : provider.baseUrl;
              _baseUrlController.text = newBaseUrl;
              _modelTextController.text = newModel;
              _update(
                _s.copyWith(
                  llmProviderKey: key,
                  llmBaseUrl: newBaseUrl,
                  llmModel: newModel,
                ),
              );
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      filled: true,
      fillColor: enabled ? const Color(0x0D2060C8) : const Color(0x06000000),
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
        borderSide: const BorderSide(color: AppTheme.borderSubtle, width: 0.8),
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
        fillColor: enabled ? const Color(0x0D2060C8) : const Color(0x06000000),
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
                  style: TextStyle(color: AppTheme.accentPrimary, fontSize: 12),
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
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
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

  Widget _buildOutputPreviewSection() {
    return Column(
      children: [
        _previewScenarioCard(
          scene: '场景 A',
          title: '直接输出',
          spoken: '呃 把昨天讨论的需求 嗯 整理一下 就是 大概是 用户可以自定义快捷键 然后 支持多语言 还有就是 历史记录功能',
          result: '把昨天讨论的需求整理一下，大概是用户可以自定义快捷键，支持多语言，还有历史记录功能。',
          darkResult: false,
        ),
        const SizedBox(height: 10),
        _previewScenarioCard(
          scene: '场景 B',
          title: '逻辑优化 (LLM)',
          spoken: '嗯 其实主要有三个需求 第一是快捷键 用户可以自己设置的那种 然后语言 这块要支持多语言 最后历史记录也得有',
          result:
              '用户需求如下：\n'
              '1. 自定义快捷键：用户可自行配置\n'
              '2. 多语言支持\n'
              '3. 历史记录：方便回顾内容',
          darkResult: true,
        ),
      ],
    );
  }

  Widget _previewScenarioCard({
    required String scene,
    required String title,
    required String spoken,
    required String result,
    required bool darkResult,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1D59),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  scene,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x0F2060C8),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    border: Border.all(
                      color: AppTheme.borderSubtle,
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '你说：',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '「$spoken」',
                        style: const TextStyle(
                          color: Color(0xFF586179),
                          fontSize: 13.5,
                          height: 1.55,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: darkResult
                        ? const Color(0xFF0D0F14)
                        : const Color(0xFFF1F4FA),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    border: Border.all(
                      color: darkResult
                          ? const Color(0x401F7AE0)
                          : AppTheme.borderSubtle,
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        darkResult ? '结构化输出：' : '粘贴结果：',
                        style: TextStyle(
                          color: darkResult
                              ? const Color(0x80FFFFFF)
                              : AppTheme.textMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result,
                        style: TextStyle(
                          color: darkResult
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontSize: 13.5,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
              final newCustom = _s.customPrompts
                  .where((p) => p.id != preset.id)
                  .toList();
              final newActiveId = _s.activePromptId == preset.id
                  ? 'direct'
                  : _s.activePromptId;
              _update(
                _s.copyWith(
                  customPrompts: newCustom,
                  activePromptId: newActiveId,
                ),
              );
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
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
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
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 5),
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
            border: Border.all(color: AppTheme.borderDefault, width: 0.8),
          ),
          child: Text(
            _permissionBusy ? '处理中...' : label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
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
      cursor: onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
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
