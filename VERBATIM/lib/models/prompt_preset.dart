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
      systemPrompt: '你是一个语音输入润色助手。任务：仅做表达优化，不改变原意。严格要求：1) 不添加原文没有的事实、观点、结论、数字、时间、人物、地点。2) 不删除关键信息，不改动立场与语气强弱。3) 允许修正口误、重复、语序和标点，使句子更通顺。4) 若原文含糊，保持含糊，不要擅自补全。只输出优化后的文本，不要任何解释。',
      builtIn: true,
    ),
    const PromptPreset(
      id: 'code',
      name: 'Code 模式',
      systemPrompt: '你是一个编程任务助手。请将以下语音识别内容提取为结构化的任务列表，每条任务用 - [ ] 开头。保持简洁明确，方便开发者审查和执行。直接输出任务列表，不要添加其他说明。',
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
