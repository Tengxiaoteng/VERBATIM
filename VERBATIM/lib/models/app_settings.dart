import 'prompt_preset.dart';

class AppSettings {
  final String hotkeyKey;
  final List<String> hotkeyModifiers;
  final String modeSwitchHotkeyKey;
  final List<String> modeSwitchHotkeyModifiers;
  final String asrBaseUrl;
  final String asrProviderKey;
  final String asrApiKey;
  final String asrModel;
  final String asrCustomUrl;
  final bool llmEnabled;
  final String llmProviderKey;
  final String llmApiKey;
  final String llmBaseUrl;
  final String llmModel;
  final String activePromptId;
  final List<PromptPreset> customPrompts;
  final bool autoStartServer;
  final bool setupCompleted;
  final String modelDownloadSource;
  final String modelDownloadMirrorUrl;

  const AppSettings({
    required this.hotkeyKey,
    required this.hotkeyModifiers,
    required this.modeSwitchHotkeyKey,
    required this.modeSwitchHotkeyModifiers,
    this.asrBaseUrl = 'http://localhost:10095',
    this.asrProviderKey = 'local',
    this.asrApiKey = '',
    this.asrModel = '',
    this.asrCustomUrl = '',
    required this.llmEnabled,
    required this.llmProviderKey,
    required this.llmApiKey,
    required this.llmBaseUrl,
    required this.llmModel,
    required this.activePromptId,
    required this.customPrompts,
    this.autoStartServer = true,
    this.setupCompleted = false,
    this.modelDownloadSource = 'auto',
    this.modelDownloadMirrorUrl = '',
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      hotkeyKey: 'Fn',
      hotkeyModifiers: [],
      modeSwitchHotkeyKey: 'Key M',
      modeSwitchHotkeyModifiers: ['alt'],
      llmEnabled: false,
      llmProviderKey: 'deepseek',
      llmApiKey: '',
      llmBaseUrl: '',
      llmModel: 'deepseek-chat',
      activePromptId: 'direct',
      customPrompts: [],
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      hotkeyKey: json['hotkeyKey'] as String? ?? 'Fn',
      hotkeyModifiers:
          (json['hotkeyModifiers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      modeSwitchHotkeyKey: json['modeSwitchHotkeyKey'] as String? ?? 'Key M',
      modeSwitchHotkeyModifiers:
          (json['modeSwitchHotkeyModifiers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['alt'],
      asrBaseUrl: json['asrBaseUrl'] as String? ?? 'http://localhost:10095',
      asrProviderKey: json['asrProviderKey'] as String? ?? 'local',
      asrApiKey: json['asrApiKey'] as String? ?? '',
      asrModel: json['asrModel'] as String? ?? '',
      asrCustomUrl: json['asrCustomUrl'] as String? ?? '',
      llmEnabled: json['llmEnabled'] as bool? ?? false,
      llmProviderKey: json['llmProviderKey'] as String? ?? 'deepseek',
      llmApiKey: json['llmApiKey'] as String? ?? '',
      llmBaseUrl: json['llmBaseUrl'] as String? ?? '',
      llmModel: json['llmModel'] as String? ?? 'deepseek-chat',
      activePromptId: json['activePromptId'] as String? ?? 'direct',
      customPrompts:
          (json['customPrompts'] as List<dynamic>?)
              ?.map((e) => PromptPreset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      autoStartServer: json['autoStartServer'] as bool? ?? true,
      setupCompleted: json['setupCompleted'] as bool? ?? false,
      modelDownloadSource: json['modelDownloadSource'] as String? ?? 'auto',
      modelDownloadMirrorUrl: json['modelDownloadMirrorUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hotkeyKey': hotkeyKey,
      'hotkeyModifiers': hotkeyModifiers,
      'modeSwitchHotkeyKey': modeSwitchHotkeyKey,
      'modeSwitchHotkeyModifiers': modeSwitchHotkeyModifiers,
      'asrBaseUrl': asrBaseUrl,
      'asrProviderKey': asrProviderKey,
      'asrApiKey': asrApiKey,
      'asrModel': asrModel,
      'asrCustomUrl': asrCustomUrl,
      'llmEnabled': llmEnabled,
      'llmProviderKey': llmProviderKey,
      'llmApiKey': llmApiKey,
      'llmBaseUrl': llmBaseUrl,
      'llmModel': llmModel,
      'activePromptId': activePromptId,
      'customPrompts': customPrompts.map((e) => e.toJson()).toList(),
      'autoStartServer': autoStartServer,
      'setupCompleted': setupCompleted,
      'modelDownloadSource': modelDownloadSource,
      'modelDownloadMirrorUrl': modelDownloadMirrorUrl,
    };
  }

  AppSettings copyWith({
    String? hotkeyKey,
    List<String>? hotkeyModifiers,
    String? modeSwitchHotkeyKey,
    List<String>? modeSwitchHotkeyModifiers,
    String? asrBaseUrl,
    String? asrProviderKey,
    String? asrApiKey,
    String? asrModel,
    String? asrCustomUrl,
    bool? llmEnabled,
    String? llmProviderKey,
    String? llmApiKey,
    String? llmBaseUrl,
    String? llmModel,
    String? activePromptId,
    List<PromptPreset>? customPrompts,
    bool? autoStartServer,
    bool? setupCompleted,
    String? modelDownloadSource,
    String? modelDownloadMirrorUrl,
  }) {
    return AppSettings(
      hotkeyKey: hotkeyKey ?? this.hotkeyKey,
      hotkeyModifiers: hotkeyModifiers ?? this.hotkeyModifiers,
      modeSwitchHotkeyKey: modeSwitchHotkeyKey ?? this.modeSwitchHotkeyKey,
      modeSwitchHotkeyModifiers:
          modeSwitchHotkeyModifiers ?? this.modeSwitchHotkeyModifiers,
      asrBaseUrl: asrBaseUrl ?? this.asrBaseUrl,
      asrProviderKey: asrProviderKey ?? this.asrProviderKey,
      asrApiKey: asrApiKey ?? this.asrApiKey,
      asrModel: asrModel ?? this.asrModel,
      asrCustomUrl: asrCustomUrl ?? this.asrCustomUrl,
      llmEnabled: llmEnabled ?? this.llmEnabled,
      llmProviderKey: llmProviderKey ?? this.llmProviderKey,
      llmApiKey: llmApiKey ?? this.llmApiKey,
      llmBaseUrl: llmBaseUrl ?? this.llmBaseUrl,
      llmModel: llmModel ?? this.llmModel,
      activePromptId: activePromptId ?? this.activePromptId,
      customPrompts: customPrompts ?? this.customPrompts,
      autoStartServer: autoStartServer ?? this.autoStartServer,
      setupCompleted: setupCompleted ?? this.setupCompleted,
      modelDownloadSource: modelDownloadSource ?? this.modelDownloadSource,
      modelDownloadMirrorUrl:
          modelDownloadMirrorUrl ?? this.modelDownloadMirrorUrl,
    );
  }
}
