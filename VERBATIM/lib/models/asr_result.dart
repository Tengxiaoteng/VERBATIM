class AsrResult {
  final int code;
  final String text;
  final String? error;

  const AsrResult({
    required this.code,
    required this.text,
    this.error,
  });

  factory AsrResult.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String?
        ?? json['result'] as String?
        ?? '';
    return AsrResult(
      code: json['code'] as int? ?? -1,
      text: text,
      error: json['error'] as String? ?? json['message'] as String?,
    );
  }

  bool get isSuccess => code == 0;
}
