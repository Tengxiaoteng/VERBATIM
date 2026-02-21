import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/asr_result.dart';

class CloudAsrService {
  final String endpoint;
  final String apiKey;
  final String model;

  const CloudAsrService({
    required this.endpoint,
    required this.apiKey,
    required this.model,
  });

  Future<AsrResult> transcribe(String filePath) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(endpoint));
      request.headers['Authorization'] = 'Bearer $apiKey';
      if (model.isNotEmpty) request.fields['model'] = model;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send().timeout(
        const Duration(minutes: 2),
      );
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final text = json['text'] as String? ?? '';
        return AsrResult(code: 0, text: text);
      } else {
        String? errMsg;
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final errObj = json['error'];
          if (errObj is Map) {
            errMsg = errObj['message'] as String?;
          }
          errMsg ??= json['message'] as String?;
        } catch (_) {}
        return AsrResult(
          code: -1,
          text: '',
          error: errMsg ?? 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      return AsrResult(code: -1, text: '', error: e.toString());
    }
  }
}
