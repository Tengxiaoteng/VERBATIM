class LlmProvider {
  final String key;
  final String name;
  final String baseUrl;
  final List<String> models;

  const LlmProvider({
    required this.key,
    required this.name,
    required this.baseUrl,
    required this.models,
  });

  static final builtIn = <LlmProvider>[
    const LlmProvider(
      key: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      models: ['deepseek-chat'],
    ),
    const LlmProvider(
      key: 'qwen',
      name: '通义千问',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      models: ['qwen-turbo', 'qwen-plus', 'qwen-max'],
    ),
    const LlmProvider(
      key: 'doubao',
      name: '豆包',
      baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      models: [],
    ),
    const LlmProvider(
      key: 'custom',
      name: '自定义',
      baseUrl: '',
      models: [],
    ),
  ];

  static LlmProvider? findByKey(String key) {
    for (final provider in builtIn) {
      if (provider.key == key) return provider;
    }
    return null;
  }
}
