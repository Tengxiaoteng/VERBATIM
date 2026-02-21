class PromptPreset {
  final String id;
  final String name;
  final String systemPrompt;
  final bool builtIn;

  const PromptPreset({
    required this.id,
    required this.name,
    required this.systemPrompt,
    this.builtIn = false,
  });

  static final defaults = <PromptPreset>[
    const PromptPreset(
      id: 'direct',
      name: '直接输出',
      systemPrompt: '',
      builtIn: true,
    ),
    const PromptPreset(
      id: 'logic',
      name: '逻辑优化',
      systemPrompt:
          '你是中文语音整理助手。你的唯一任务是整理“原文”，不是回答原文里的问题。'
          '请在不改变原意的前提下，清理口头禅、重复和语序，让内容更清晰连贯。'
          '不要新增信息，不要给建议，不要解释。只输出整理后的文本。',
      builtIn: true,
    ),
    const PromptPreset(
      id: 'code',
      name: 'Code 模式',
      systemPrompt:
          '你是一个编程任务助手。请将以下语音识别内容提取为结构化的任务列表，每条任务用 - [ ] 开头。保持简洁明确，方便开发者审查和执行。直接输出任务列表，不要添加其他说明。',
      builtIn: true,
    ),
  ];

  factory PromptPreset.fromJson(Map<String, dynamic> json) {
    return PromptPreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      builtIn: json['builtIn'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'systemPrompt': systemPrompt,
      'builtIn': builtIn,
    };
  }
}
