import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/asr_result.dart';

class AsrApiService {
  final String baseUrl;

  AsrApiService({this.baseUrl = 'http://localhost:10095'});

  Future<AsrResult> transcribe(String filePath) async {
    final uri = Uri.parse('$baseUrl/asr');
    final stopwatch = Stopwatch()..start();
    debugPrint('[ASR] Transcribe start: uri=$uri, filePath=$filePath');

    final file = File(filePath);
    final exists = await file.exists();
    final fileSize = exists ? await file.length() : -1;
    debugPrint('[ASR] Input file check: exists=$exists, size=$fileSize');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    debugPrint(
      '[ASR] Multipart prepared: field=file, files=${request.files.length}',
    );

    final streamedResponse = await request.send().timeout(
      const Duration(minutes: 5),
    );
    final response = await http.Response.fromStream(streamedResponse);
    debugPrint(
      '[ASR] HTTP done: status=${response.statusCode}, '
      'elapsedMs=${stopwatch.elapsedMilliseconds}',
    );
    debugPrint('[ASR] Response preview: ${_preview(response.body)}');

    if (response.statusCode == 200) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = AsrResult.fromJson(json);
        debugPrint(
          '[ASR] Parsed result: code=${result.code}, '
          'textLen=${result.text.length}, error=${result.error}',
        );
        return result;
      } catch (e, st) {
        debugPrint('[ASR] JSON parse failed: $e');
        debugPrint('[ASR] JSON parse stack: $st');
        rethrow;
      }
    } else {
      debugPrint('[ASR] Non-200 response encountered');
      return AsrResult(
        code: -1,
        text: '',
        error: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }
  }

  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      debugPrint('[ASR] Health check start: uri=$uri');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      debugPrint('[ASR] Health check status=${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[ASR] Health check error: $e');
      return false;
    }
  }

  String _preview(String raw) {
    const maxLen = 240;
    final compact = raw.replaceAll('\n', ' ');
    if (compact.length <= maxLen) return compact;
    return '${compact.substring(0, maxLen)}...';
  }
}
