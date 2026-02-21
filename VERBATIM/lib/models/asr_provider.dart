class AsrProvider {
  final String key;
  final String name;
  final String endpoint; // full URL including path; empty for local
  final String defaultModel;
  final bool requiresApiKey;

  const AsrProvider({
    required this.key,
    required this.name,
    required this.endpoint,
    required this.defaultModel,
    required this.requiresApiKey,
  });

  static final builtIn = <AsrProvider>[
    const AsrProvider(
      key: 'local',
      name: '本地 FunASR',
      endpoint: '',
      defaultModel: '',
      requiresApiKey: false,
    ),
    const AsrProvider(
      key: 'openai',
      name: 'OpenAI Whisper',
      endpoint: 'https://api.openai.com/v1/audio/transcriptions',
      defaultModel: 'whisper-1',
      requiresApiKey: true,
    ),
    const AsrProvider(
      key: 'groq',
      name: 'Groq (免费)',
      endpoint: 'https://api.groq.com/openai/v1/audio/transcriptions',
      defaultModel: 'whisper-large-v3-turbo',
      requiresApiKey: true,
    ),
    const AsrProvider(
      key: 'siliconflow',
      name: 'SiliconFlow (中文优化)',
      endpoint: 'https://api.siliconflow.cn/v1/audio/transcriptions',
      defaultModel: 'FunAudioLLM/SenseVoiceSmall',
      requiresApiKey: true,
    ),
    const AsrProvider(
      key: 'iflytek',
      name: '讯飞 iFlytek（中文优秀）',
      endpoint: 'wss://iat.xf-yun.com/v1',
      defaultModel: 'zh_cn',
      requiresApiKey: true,
    ),
    const AsrProvider(
      key: 'custom',
      name: '自定义',
      endpoint: '',
      defaultModel: '',
      requiresApiKey: true,
    ),
  ];

  static AsrProvider? findByKey(String key) {
    for (final provider in builtIn) {
      if (provider.key == key) return provider;
    }
    return null;
  }
}
