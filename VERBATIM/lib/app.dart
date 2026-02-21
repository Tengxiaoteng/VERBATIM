import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'models/app_settings.dart';
import 'models/asr_provider.dart';
import 'models/asr_result.dart';
import 'theme/app_theme.dart';
import 'models/history_entry.dart';
import 'models/llm_provider.dart';
import 'models/prompt_preset.dart';
import 'services/history_service.dart';
import 'services/hotkey_service.dart';
import 'services/tray_service.dart';
import 'services/paste_service.dart';
import 'services/audio_recorder_service.dart';
import 'services/asr_api_service.dart';
import 'services/cloud_asr_service.dart';
import 'services/iflytek_asr_service.dart';
import 'services/settings_service.dart';
import 'services/llm_service.dart';
import 'services/funasr_server_service.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/result_popup.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_wizard_screen.dart';
import 'services/install_service.dart';
import 'widgets/status_indicator.dart';

class VerbatimApp extends StatefulWidget {
  final AppSettings initialSettings;
  final SettingsService settingsService;

  const VerbatimApp({
    super.key,
    required this.initialSettings,
    required this.settingsService,
  });

  @override
  State<VerbatimApp> createState() => _VerbatimAppState();
}

class _VerbatimAppState extends State<VerbatimApp> {
  final _recorder = AudioRecorderService();
  late AsrApiService _asrApi;
  CloudAsrService? _cloudAsrApi;
  IflytekAsrService? _iflytekAsrApi;
  final _pasteService = PasteService();
  final _llmService = LlmService();
  final _installService = InstallService();
  final _historyService = HistoryService();
  late final HotkeyService _recordHotkeyService;
  late final HotkeyService _modeHotkeyService;
  late final TrayService _trayService;
  late final FunasrServerService _funasrServer;

  late AppSettings _settings;
  AppStatus _status = AppStatus.idle;
  String _resultText = '';
  String _rawResultText = '';
  String _resultModeId = 'direct';
  String? _errorMessage;
  Timer? _timer;
  Timer? _modeHintTimer;
  int _recordSeconds = 0;
  bool _modeHotkeyPressed = false;
  bool _modeHintVisible = false;
  bool _modeHintInline = false;
  String _modeHintText = '';
  bool _settingsVisible = false;
  bool _historyVisible = false;
  bool _showSetupWizard = false;
  bool? _serverOnline;
  FunasrServerStatus _serverStatus = FunasrServerStatus.stopped;
  String? _serverError;
  double _downloadProgress = 0.0;
  String? _downloadLabel;
  String? _pasteTargetBundleId;
  bool? _accessibilityGranted;
  bool? _microphoneGranted;
  bool? _recAvailable;
  bool _permissionChecking = false;
  List<HistoryEntry> _historyEntries = [];

  bool get _isLocalAsr => _settings.asrProviderKey == 'local';
  static const List<String> _quickModeIds = ['direct', 'logic', 'code'];

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    _asrApi = AsrApiService(baseUrl: _settings.asrBaseUrl);
    _recordHotkeyService = HotkeyService(
      onKeyDown: _onHotkeyDown,
      onKeyUp: _onHotkeyUp,
    );
    _modeHotkeyService = HotkeyService(
      onKeyDown: _onModeHotkeyDown,
      onKeyUp: _onModeHotkeyUp,
    );
    _trayService = TrayService(
      onToggleSettings: _toggleSettings,
      onQuit: _quit,
    );
    _funasrServer = FunasrServerService(
      onStatusChanged: _onServerStatusChanged,
      onErrorChanged: (e) {
        if (mounted) setState(() => _serverError = e);
      },
      onDownloadProgress: (progress, label) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            _downloadLabel = label;
          });
        }
      },
    );
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _modeHintTimer?.cancel();
    _recordHotkeyService.dispose();
    _modeHotkeyService.dispose();
    _trayService.dispose();
    _recorder.dispose();
    _funasrServer.dispose();
    super.dispose();
  }

  /// Build (or clear) the cloud ASR service from [settings].
  void _buildCloudAsrService(AppSettings settings) {
    _cloudAsrApi = null;
    _iflytekAsrApi = null;

    if (settings.asrProviderKey == 'local') return;

    if (settings.asrProviderKey == 'iflytek') {
      if (settings.asrApiKey.isEmpty) return;
      try {
        _iflytekAsrApi = IflytekAsrService.fromCombinedKey(
          settings.asrApiKey,
          language: settings.asrModel.isNotEmpty ? settings.asrModel : 'zh_cn',
        );
      } catch (_) {}
      return;
    }

    final provider = AsrProvider.findByKey(settings.asrProviderKey);
    final endpoint = settings.asrProviderKey == 'custom'
        ? settings.asrCustomUrl
        : (provider?.endpoint ?? '');
    if (endpoint.isEmpty || settings.asrApiKey.isEmpty) return;
    final model = settings.asrModel.isNotEmpty
        ? settings.asrModel
        : (provider?.defaultModel ?? '');
    _cloudAsrApi = CloudAsrService(
      endpoint: endpoint,
      apiKey: settings.asrApiKey,
      model: model,
    );
  }

  Future<void> _init() async {
    _historyEntries = await _historyService.load();
    await _trayService.init();
    await _registerHotkeys();

    // Build cloud ASR service if configured
    _buildCloudAsrService(_settings);

    if (!_settings.setupCompleted) {
      // First launch: show the setup wizard, don't start the server
      // or request any permissions yet.
      setState(() => _showSetupWizard = true);
      await windowManager.setSize(const Size(500, 620));
      await windowManager.center();
      await windowManager.show();
      return;
    }

    // Normal launch: start server (local only), do a silent permission check.
    if (_isLocalAsr) {
      if (_settings.autoStartServer) {
        _funasrServer.start(
          baseUrl: _settings.asrBaseUrl,
          modelDownloadSource: _settings.modelDownloadSource,
          modelDownloadMirrorUrl: _settings.modelDownloadMirrorUrl,
        );
      } else {
        _checkServerHealth();
      }
    }
    await _runStartupPermissionGuide();
  }

  void _onServerStatusChanged(FunasrServerStatus status) {
    if (!mounted) return;
    setState(() {
      _serverStatus = status;
      _serverOnline = status == FunasrServerStatus.ready;
      // Clear download progress only once the server is fully ready or errored.
      // The download can happen during both 'starting' and 'loadingModels'
      // phases (modelscope downloads before the model is actually loaded),
      // so keep progress visible until we leave those phases.
      if (status == FunasrServerStatus.ready ||
          status == FunasrServerStatus.error ||
          status == FunasrServerStatus.stopped) {
        _downloadProgress = 0.0;
        _downloadLabel = null;
      }
    });
  }

  Future<void> _restartServer() async {
    await _funasrServer.stop();
    _funasrServer.start(
      baseUrl: _settings.asrBaseUrl,
      modelDownloadSource: _settings.modelDownloadSource,
      modelDownloadMirrorUrl: _settings.modelDownloadMirrorUrl,
    );
  }

  Future<void> _checkServerHealth() async {
    final online = await _asrApi.checkHealth();
    if (mounted) setState(() => _serverOnline = online);
  }

  void _quit() {
    _timer?.cancel();
    _modeHintTimer?.cancel();
    _recordHotkeyService.dispose();
    _modeHotkeyService.dispose();
    _trayService.dispose();
    _recorder.dispose();
    _funasrServer.dispose();
    exit(0);
  }

  Future<void> _registerHotkeys() async {
    try {
      await _recordHotkeyService.register(
        key: HotkeyService.parseKey(_settings.hotkeyKey),
        modifiers: HotkeyService.parseModifiers(_settings.hotkeyModifiers),
      );
    } catch (e) {
      debugPrint('[Hotkey] Failed to register record hotkey: $e');
    }

    final sameCombination =
        _settings.hotkeyKey == _settings.modeSwitchHotkeyKey &&
        _settings.hotkeyModifiers.join(',') ==
            _settings.modeSwitchHotkeyModifiers.join(',');
    if (sameCombination) {
      debugPrint('[Hotkey] Mode hotkey skipped: same as record hotkey');
      return;
    }

    try {
      await _modeHotkeyService.register(
        key: HotkeyService.parseKey(_settings.modeSwitchHotkeyKey),
        modifiers: HotkeyService.parseModifiers(
          _settings.modeSwitchHotkeyModifiers,
        ),
      );
    } catch (e) {
      debugPrint('[Hotkey] Failed to register mode hotkey: $e');
    }
  }

  Future<void> _unregisterHotkeys() async {
    await _recordHotkeyService.unregister();
    await _modeHotkeyService.unregister();
  }

  // ── Hotkey listening state (temporarily unregister while picking) ──

  void _onHotkeyListeningStateChanged(bool listening) {
    if (listening) {
      unawaited(_unregisterHotkeys());
    } else {
      unawaited(_registerHotkeys());
    }
  }

  // ── Settings changed callback ─────────────────────────────────────

  Future<void> _onSettingsChanged(AppSettings newSettings) async {
    final oldSettings = _settings;
    final recordHotkeyChanged =
        newSettings.hotkeyKey != oldSettings.hotkeyKey ||
        newSettings.hotkeyModifiers.join(',') !=
            oldSettings.hotkeyModifiers.join(',');
    final modeHotkeyChanged =
        newSettings.modeSwitchHotkeyKey != oldSettings.modeSwitchHotkeyKey ||
        newSettings.modeSwitchHotkeyModifiers.join(',') !=
            oldSettings.modeSwitchHotkeyModifiers.join(',');

    final asrUrlChanged = newSettings.asrBaseUrl != oldSettings.asrBaseUrl;
    final autoStartChanged =
        newSettings.autoStartServer != oldSettings.autoStartServer;
    final asrProviderChanged =
        newSettings.asrProviderKey != oldSettings.asrProviderKey;
    final cloudAsrChanged =
        asrProviderChanged ||
        newSettings.asrApiKey != oldSettings.asrApiKey ||
        newSettings.asrModel != oldSettings.asrModel ||
        newSettings.asrCustomUrl != oldSettings.asrCustomUrl;

    setState(() => _settings = newSettings);
    await widget.settingsService.save(newSettings);

    // Rebuild cloud ASR service whenever any related setting changes
    if (cloudAsrChanged) {
      _buildCloudAsrService(newSettings);
    }

    // Switching from local → cloud: stop the local server
    if (asrProviderChanged && oldSettings.asrProviderKey == 'local') {
      await _funasrServer.stop();
    }

    // Switching from cloud → local: start server per autoStart setting
    if (asrProviderChanged && newSettings.asrProviderKey == 'local') {
      if (newSettings.autoStartServer &&
          _serverStatus != FunasrServerStatus.ready &&
          _serverStatus != FunasrServerStatus.starting &&
          _serverStatus != FunasrServerStatus.loadingModels) {
        _funasrServer.start(
          baseUrl: newSettings.asrBaseUrl,
          modelDownloadSource: newSettings.modelDownloadSource,
          modelDownloadMirrorUrl: newSettings.modelDownloadMirrorUrl,
        );
      } else {
        _checkServerHealth();
      }
    }

    // Handle ASR URL change (local only)
    if (asrUrlChanged && _isLocalAsr) {
      _asrApi = AsrApiService(baseUrl: newSettings.asrBaseUrl);
      if (newSettings.autoStartServer) {
        _restartServer();
      } else {
        _checkServerHealth();
      }
    }

    // Handle autoStartServer toggle (local only)
    if (autoStartChanged && !asrUrlChanged && _isLocalAsr) {
      if (newSettings.autoStartServer &&
          _serverStatus != FunasrServerStatus.ready &&
          _serverStatus != FunasrServerStatus.starting &&
          _serverStatus != FunasrServerStatus.loadingModels) {
        _funasrServer.start(
          baseUrl: newSettings.asrBaseUrl,
          modelDownloadSource: newSettings.modelDownloadSource,
          modelDownloadMirrorUrl: newSettings.modelDownloadMirrorUrl,
        );
      } else if (!newSettings.autoStartServer &&
          (_serverStatus == FunasrServerStatus.starting ||
              _serverStatus == FunasrServerStatus.loadingModels)) {
        _funasrServer.stop();
      }
    }

    if (recordHotkeyChanged) {
      await _recordHotkeyService.reRegister(
        key: HotkeyService.parseKey(newSettings.hotkeyKey),
        modifiers: HotkeyService.parseModifiers(newSettings.hotkeyModifiers),
      );
    }

    if (modeHotkeyChanged) {
      await _modeHotkeyService.reRegister(
        key: HotkeyService.parseKey(newSettings.modeSwitchHotkeyKey),
        modifiers: HotkeyService.parseModifiers(
          newSettings.modeSwitchHotkeyModifiers,
        ),
      );
    }
  }

  // ── Settings window ───────────────────────────────────────────────

  Future<void> _toggleSettings() async {
    if (_status != AppStatus.idle) return; // Don't toggle during recording

    if (_settingsVisible || _historyVisible) {
      await windowManager.hide();
      setState(() {
        _settingsVisible = false;
        _historyVisible = false;
      });
    } else {
      await _showSettingsWindow();
    }
  }

  Future<void> _showSettingsWindow() async {
    setState(() {
      _settingsVisible = true;
      _historyVisible = false;
    });
    await windowManager.setSize(const Size(420, 600));
    await _positionWindow(forSettings: true);
    await windowManager.show();
  }

  Future<void> _showHistory() async {
    setState(() {
      _historyVisible = true;
      _settingsVisible = false;
    });
    await windowManager.setSize(const Size(420, 600));
    await _positionWindow(forSettings: true);
    await windowManager.show();
  }

  void _backFromHistory() {
    setState(() {
      _historyVisible = false;
      _settingsVisible = true;
    });
  }

  Future<void> _deleteHistoryEntry(String id) async {
    final updated = await _historyService.deleteEntry(_historyEntries, id);
    if (mounted) setState(() => _historyEntries = updated);
  }

  Future<void> _clearHistory() async {
    final updated = await _historyService.clearAll();
    if (mounted) setState(() => _historyEntries = updated);
  }

  Future<void> _refreshPermissionStatus() async {
    if (_permissionChecking) return;
    _permissionChecking = true;
    try {
      final recAvailable = await _recorder.hasPermission();
      final accessibility = await _pasteService.checkAccessibilityPermission();
      final microphone = await _pasteService.checkMicrophonePermission();
      if (!mounted) return;
      setState(() {
        _recAvailable = recAvailable;
        _accessibilityGranted = accessibility;
        _microphoneGranted = microphone;
      });
    } finally {
      _permissionChecking = false;
    }
  }

  Future<void> _requestAccessibilityPermission() async {
    await _pasteService.openAccessibilitySettings();
    await Future.delayed(const Duration(milliseconds: 200));
    await _refreshPermissionStatus();
  }

  Future<void> _requestMicrophonePermission() async {
    final granted = await _pasteService.requestMicrophonePermission();
    if (!granted) {
      await _pasteService.openMicrophoneSettings();
    }
    await Future.delayed(const Duration(milliseconds: 200));
    await _refreshPermissionStatus();
  }

  Future<void> _runStartupPermissionGuide() async {
    // Silent check only — no system dialogs, no permission prompts.
    await _refreshPermissionStatus();

    final needsGuide =
        _recAvailable != true ||
        _microphoneGranted != true ||
        _accessibilityGranted != true;
    if (needsGuide) {
      await _showSettingsWindow();
    }
  }

  Future<void> _onSetupComplete() async {
    // Mark setup as done and persist.
    final updated = _settings.copyWith(setupCompleted: true);
    setState(() {
      _settings = updated;
      _showSetupWizard = false;
    });
    await widget.settingsService.save(updated);

    // Now start the server (local only) and do a silent permission check.
    if (_isLocalAsr) {
      if (_settings.autoStartServer) {
        _funasrServer.start(
          baseUrl: _settings.asrBaseUrl,
          modelDownloadSource: _settings.modelDownloadSource,
          modelDownloadMirrorUrl: _settings.modelDownloadMirrorUrl,
        );
      } else {
        _checkServerHealth();
      }
    }
    await _refreshPermissionStatus();

    // Resize back to hidden (idle) state.
    await windowManager.hide();
  }

  void _onSetupSkip() {
    unawaited(_onSetupComplete());
  }

  // ── Hotkey callbacks ──────────────────────────────────────────────

  void _onHotkeyDown() {
    if (_status != AppStatus.idle) return;
    unawaited(_startRecording());
  }

  void _onHotkeyUp() {
    if (_status != AppStatus.recording) return;
    unawaited(_stopAndTranscribe());
  }

  void _onModeHotkeyDown() {
    if (_status != AppStatus.idle || _modeHotkeyPressed) return;
    _modeHotkeyPressed = true;
    unawaited(_switchToNextMode());
  }

  void _onModeHotkeyUp() {
    _modeHotkeyPressed = false;
  }

  Future<void> _switchToNextMode() async {
    if (_quickModeIds.isEmpty) return;
    final currentIndex = _quickModeIds.indexOf(_settings.activePromptId);
    final nextIndex = currentIndex >= 0
        ? (currentIndex + 1) % _quickModeIds.length
        : 0;
    final nextModeId = _quickModeIds[nextIndex];

    final updated = _settings.copyWith(activePromptId: nextModeId);
    if (!mounted) return;
    setState(() => _settings = updated);
    await widget.settingsService.save(updated);

    final modeName = _modeNameById(nextModeId);
    await _showModeHint('已切换模式：$modeName');
  }

  String _modeNameById(String id) {
    final prompts = [...PromptPreset.defaults, ..._settings.customPrompts];
    for (final p in prompts) {
      if (p.id == id) return p.name;
    }
    return '直接输出';
  }

  bool _isStructuredMode(String id) => id == 'logic' || id == 'code';

  // ── Recording flow ────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_status == AppStatus.recording) return;
    _timer?.cancel();
    _modeHintTimer?.cancel();
    if (_modeHintVisible && mounted) {
      setState(() {
        _modeHintVisible = false;
        _modeHintInline = false;
      });
    }

    await _refreshPermissionStatus();

    if (_recAvailable != true) {
      await _showError('未找到 rec 命令。请先安装 SoX: brew install sox');
      await _showSettingsWindow();
      return;
    }
    if (_microphoneGranted != true) {
      await _requestMicrophonePermission();
      if (_microphoneGranted != true) {
        await _showError('未获得麦克风权限，请在系统设置里允许后重试');
        await _showSettingsWindow();
        return;
      }
    }

    // Capture current target app so we can paste back to its cursor later.
    _pasteTargetBundleId = await _pasteService.getFrontmostBundleId();

    // Hide settings if visible
    if (_settingsVisible) {
      await windowManager.hide();
    }

    setState(() {
      _status = AppStatus.recording;
      _recordSeconds = 0;
      _errorMessage = null;
      _resultText = '';
      _settingsVisible = false;
    });

    try {
      await _recorder.start();

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });

      await _showOverlay();
    } catch (e) {
      debugPrint('[App] Start recording error: $e');
      _showError('录音启动失败: $e');
    }
  }

  Future<void> _stopAndTranscribe() async {
    _timer?.cancel();
    setState(() => _status = AppStatus.processing);
    debugPrint('[App] Stop recording and transcribe flow started');

    try {
      final path = await _recorder.stop();
      debugPrint('[App] Recorder stop result path=$path');
      if (path == null || path.isEmpty) {
        final recorderError = _recorder.lastError;
        _showError(recorderError ?? '录音文件为空');
        return;
      }

      try {
        final file = File(path);
        final exists = await file.exists();
        final size = exists ? await file.length() : -1;
        debugPrint(
          '[App] Recorded file check: exists=$exists, size=$size, path=$path',
        );
      } catch (e, st) {
        debugPrint('[App] Recorded file stat failed: $e');
        debugPrint('[App] Recorded file stat stack: $st');
      }

      // Validate WAV file before sending to ASR
      final wavError = await AudioRecorderService.validateWavFile(path);
      if (wavError != null) {
        debugPrint('[App] WAV validation failed: $wavError');
        _showError('录音文件无效: $wavError');
        return;
      }

      // Route to local or cloud ASR
      final AsrResult result;
      if (_isLocalAsr) {
        result = await _asrApi.transcribe(path);
      } else if (_iflytekAsrApi != null) {
        result = await _iflytekAsrApi!.transcribe(path);
      } else if (_cloudAsrApi != null) {
        result = await _cloudAsrApi!.transcribe(path);
      } else {
        _showError('云端 ASR 未配置，请在设置中填写 API Key');
        return;
      }

      debugPrint(
        '[App] ASR result received: '
        'code=${result.code}, textLen=${result.text.length}, error=${result.error}',
      );

      if (result.isSuccess && result.text.isNotEmpty) {
        // Run LLM post-processing if enabled
        final textToPaste = await _processWithLlm(result.text);
        debugPrint('[App] LLM processed textLen=${textToPaste.length}');

        // Hide overlay so the previous app regains focus
        await windowManager.hide();
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;

        final pasteResult = await _pasteService.pasteToFrontApp(
          textToPaste,
          preferredBundleId: _pasteTargetBundleId,
        );

        // Save to history regardless of paste outcome
        final entry = HistoryEntry(
          id: 'h_${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          rawText: result.text,
          processedText: textToPaste,
          durationSeconds: _recordSeconds,
        );
        final updatedHistory = await _historyService.addEntry(
          _historyEntries,
          entry,
        );
        if (mounted) setState(() => _historyEntries = updatedHistory);

        if (pasteResult.success) {
          if (mounted) {
            setState(() {
              _status = AppStatus.idle;
              _settingsVisible = false;
            });
          }
          _pasteTargetBundleId = null;
        } else {
          if (pasteResult.permissionDenied) {
            await _pasteService.openAccessibilitySettings();
            await _refreshPermissionStatus();
            _showError(
              '自动粘贴被系统拦截：请在"系统设置 > 隐私与安全性 > 辅助功能"允许本应用发送按键（文本已复制到剪贴板）',
            );
            return;
          }

          // Paste failed — show result popup as fallback
          if (mounted) {
            setState(() {
              _status = AppStatus.done;
              _resultText = textToPaste;
              _rawResultText = result.text;
              _resultModeId = _settings.activePromptId;
            });
          }
          if (!mounted) return;
          await windowManager.setSize(const Size(980, 560));
          await _positionWindow();
          await windowManager.show();
        }
      } else {
        final String msg;
        if (result.isSuccess && result.text.isEmpty) {
          msg = '未识别到语音内容（服务器返回空文本）';
        } else if (!result.isSuccess &&
            result.error != null &&
            result.error!.isNotEmpty) {
          msg = '识别失败: ${result.error}';
        } else if (!result.isSuccess) {
          msg = '识别失败 (code: ${result.code})';
        } else {
          msg = '未识别到语音内容';
        }
        debugPrint('[App] ASR considered failed; user message="$msg"');
        _showError(msg);
      }
    } catch (e, st) {
      debugPrint('[App] Transcribe error: $e');
      debugPrint('[App] Transcribe stack: $st');
      _showError('处理失败: $e');
    }
  }

  /// Run LLM post-processing on the raw ASR text if enabled and a non-direct
  /// prompt is selected. Returns the original text on failure or when disabled.
  Future<String> _processWithLlm(String rawText) async {
    if (!_settings.llmEnabled || _settings.activePromptId == 'direct') {
      return rawText;
    }

    // Find the active prompt
    final allPrompts = [...PromptPreset.defaults, ..._settings.customPrompts];
    PromptPreset? activePrompt;
    for (final p in allPrompts) {
      if (p.id == _settings.activePromptId) {
        activePrompt = p;
        break;
      }
    }
    if (activePrompt == null || activePrompt.systemPrompt.isEmpty) {
      return rawText;
    }

    // Resolve base URL
    String resolvedBaseUrl;
    if (_settings.llmProviderKey != 'custom') {
      final provider = LlmProvider.findByKey(_settings.llmProviderKey);
      resolvedBaseUrl = provider?.baseUrl ?? _settings.llmBaseUrl;
    } else {
      resolvedBaseUrl = _settings.llmBaseUrl;
    }

    if (_settings.llmApiKey.isEmpty || resolvedBaseUrl.isEmpty) {
      debugPrint(
        '[App] LLM enabled but API key or base URL is empty, skipping',
      );
      return rawText;
    }

    final llmOutput = await _llmService.process(
      text: rawText,
      systemPrompt: activePrompt.systemPrompt,
      apiKey: _settings.llmApiKey,
      baseUrl: resolvedBaseUrl,
      model: _settings.llmModel,
    );

    // Logic mode now prefers structure but does not enforce a fixed template.
    if (activePrompt.id == 'logic') {
      return _cleanupLlmOutput(llmOutput, rawText);
    }

    return llmOutput;
  }

  String _cleanupLlmOutput(String output, String fallbackText) {
    final cleaned = output
        .replaceAll('```', '')
        .replaceAll(RegExp(r'^\s*[-*]\s*', multiLine: true), '')
        .trim();
    return cleaned.isEmpty ? fallbackText : cleaned;
  }

  // ── Helpers ───────────────────────────────────────────────────────

  Future<void> _showError(String message) async {
    _modeHintTimer?.cancel();
    setState(() {
      _status = AppStatus.error;
      _errorMessage = message;
      _modeHintVisible = false;
      _modeHintInline = false;
    });
    _pasteTargetBundleId = null;
    await _showOverlay();

    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted && _status == AppStatus.error) {
        windowManager.hide();
        setState(() {
          _status = AppStatus.idle;
          _settingsVisible = false;
        });
      }
    });
  }

  Future<void> _showModeHint(String message) async {
    _modeHintTimer?.cancel();
    final inline = _settingsVisible || _historyVisible || _showSetupWizard;
    if (mounted) {
      setState(() {
        _modeHintText = message;
        _modeHintVisible = true;
        _modeHintInline = inline;
      });
    }

    if (!inline) {
      await windowManager.setSize(const Size(280, 72));
      await _positionModeHintWindow();
      await windowManager.show();
    }

    _modeHintTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      if (_modeHintVisible && _status == AppStatus.idle) {
        if (_modeHintInline) {
          setState(() {
            _modeHintVisible = false;
            _modeHintInline = false;
          });
          return;
        }
        windowManager.hide();
        setState(() {
          _modeHintVisible = false;
          _modeHintInline = false;
        });
      }
    });
  }

  Future<void> _showOverlay() async {
    await windowManager.setSize(const Size(280, 80));
    await _positionWindow();
    await windowManager.show();
  }

  Future<void> _positionModeHintWindow() async {
    await windowManager.setAlignment(Alignment.bottomRight);
    final pos = await windowManager.getPosition();
    await windowManager.setPosition(Offset(pos.dx - 24, pos.dy - 24));
  }

  Future<void> _positionWindow({bool forSettings = false}) async {
    if (forSettings) {
      await windowManager.center();
    } else {
      await windowManager.setAlignment(Alignment.bottomCenter);
      final pos = await windowManager.getPosition();
      await windowManager.setPosition(Offset(pos.dx, pos.dy - 80));
    }
  }

  void _dismissResult() {
    windowManager.hide();
    setState(() {
      _status = AppStatus.idle;
      _settingsVisible = false;
      _resultText = '';
      _rawResultText = '';
      _resultModeId = 'direct';
      _modeHintInline = false;
      _modeHintVisible = false;
    });
  }

  Widget _buildPageWithInlineModeHint(Widget child) {
    if (!_modeHintVisible || !_modeHintInline) return child;
    return Stack(
      children: [
        child,
        Positioned(
          right: 16,
          bottom: 16,
          child: IgnorePointer(child: ModeSwitchHintCard(message: _modeHintText)),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(),
      home: Scaffold(backgroundColor: Colors.transparent, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    // Recording / processing / error overlay takes priority
    if (_status == AppStatus.recording ||
        _status == AppStatus.processing ||
        _status == AppStatus.error) {
      return RecordingOverlay(
        isRecording: _status == AppStatus.recording,
        isProcessing: _status == AppStatus.processing,
        recordSeconds: _recordSeconds,
        errorMessage: _status == AppStatus.error ? _errorMessage : null,
      );
    }

    if (_modeHintVisible && !_modeHintInline) {
      return ModeSwitchOverlay(message: _modeHintText);
    }

    // Result popup (paste failed fallback)
    if (_status == AppStatus.done) {
      return ResultPopup(
        rawText: _rawResultText,
        processedText: _resultText,
        modeTitle: _modeNameById(_resultModeId),
        structured: _isStructuredMode(_resultModeId),
        onDismiss: _dismissResult,
      );
    }

    // Setup wizard (first launch)
    if (_showSetupWizard) {
      return _buildPageWithInlineModeHint(
        SetupWizardScreen(
        pasteService: _pasteService,
        installService: _installService,
        asrProviderKey: _settings.asrProviderKey,
        onAsrProviderKeyChanged: (providerKey) async {
          final updated = _settings.copyWith(asrProviderKey: providerKey);
          if (!mounted) return;
          setState(() => _settings = updated);
          await widget.settingsService.save(updated);
          _buildCloudAsrService(updated);
        },
        modelDownloadSource: _settings.modelDownloadSource,
        modelDownloadMirrorUrl: _settings.modelDownloadMirrorUrl,
        onModelDownloadConfigChanged: (source, mirrorUrl) async {
          final updated = _settings.copyWith(
            modelDownloadSource: source,
            modelDownloadMirrorUrl: mirrorUrl,
          );
          if (!mounted) return;
          setState(() => _settings = updated);
          await widget.settingsService.save(updated);
        },
        onComplete: _onSetupComplete,
        onSkip: _onSetupSkip,
        ),
      );
    }

    // History panel
    if (_historyVisible) {
      return _buildPageWithInlineModeHint(
        HistoryScreen(
        entries: _historyEntries,
        onBack: _backFromHistory,
        onDelete: _deleteHistoryEntry,
        onClearAll: _clearHistory,
        ),
      );
    }

    // Settings panel
    if (_settingsVisible) {
      return _buildPageWithInlineModeHint(
        SettingsScreen(
        onQuit: _quit,
        settings: _settings,
        onSettingsChanged: _onSettingsChanged,
        serverOnline: _serverOnline,
        serverStatus: _serverStatus,
        serverError: _serverError,
        downloadProgress: _downloadProgress,
        downloadLabel: _downloadLabel,
        onRefreshServer: _checkServerHealth,
        onRestartServer: _restartServer,
        onHotkeyListeningStateChanged: _onHotkeyListeningStateChanged,
        accessibilityGranted: _accessibilityGranted,
        microphoneGranted: _microphoneGranted,
        recAvailable: _recAvailable,
        onRefreshPermissions: _refreshPermissionStatus,
        onRequestAccessibilityPermission: _requestAccessibilityPermission,
        onRequestMicrophonePermission: _requestMicrophonePermission,
        onShowHistory: _showHistory,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
