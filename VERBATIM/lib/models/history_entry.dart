class HistoryEntry {
  final String id;
  final DateTime timestamp;
  final String rawText;
  final String processedText;
  final int durationSeconds;

  const HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.rawText,
    required this.processedText,
    required this.durationSeconds,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      rawText: json['rawText'] as String? ?? '',
      processedText: json['processedText'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'rawText': rawText,
        'processedText': processedText,
        'durationSeconds': durationSeconds,
      };
}
