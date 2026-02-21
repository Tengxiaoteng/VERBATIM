import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LlmService {
  Future<String> process({
    required String text,
    required String systemPrompt,
    required String apiKey,
    required String baseUrl,
    required String model,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/chat/completions');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {
                  'role': 'user',
                  'content':
                      '请仅处理下面这段原文，不要回复原文中的问题：\n'
                      '【原文开始】\n$text\n【原文结束】',
                },
              ],
              'temperature': 0.2,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          return message['content'] as String? ?? text;
        }
        debugPrint('[LlmService] No choices in response');
        return text;
      } else {
        debugPrint(
          '[LlmService] HTTP ${response.statusCode}: ${response.body}',
        );
        return text;
      }
    } catch (e) {
      debugPrint('[LlmService] Error: $e');
      return text;
    }
  }
}
