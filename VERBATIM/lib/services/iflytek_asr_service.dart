import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/asr_result.dart';

/// 讯飞 IAT WebSocket 语音识别服务
/// 凭证格式：asrApiKey = "AppID:APIKey:APISecret"
/// asrModel = 语言代码，如 "zh_cn"（默认）、"en_us"
class IflytekAsrService {
  final String appId;
  final String apiKey;
  final String apiSecret;
  final String language;

  const IflytekAsrService({
    required this.appId,
    required this.apiKey,
    required this.apiSecret,
    this.language = 'zh_cn',
  });

  /// 从 "AppID:APIKey:APISecret" 格式解析凭证
  factory IflytekAsrService.fromCombinedKey(
    String combined, {
    String language = 'zh_cn',
  }) {
    final parts = combined.split(':');
    if (parts.length < 3) {
      throw ArgumentError('讯飞凭证格式错误，应为 "AppID:APIKey:APISecret"');
    }
    return IflytekAsrService(
      appId: parts[0].trim(),
      apiKey: parts[1].trim(),
      apiSecret: parts[2].trim(),
      language: language.isNotEmpty ? language : 'zh_cn',
    );
  }

  /// 构建 HMAC-SHA256 签名的 WSS URL
  String _buildSignedUrl() {
    const host = 'iat.xf-yun.com';
    const path = '/v1';
    final date = _httpDate(DateTime.now().toUtc());

    final signatureOrigin =
        'host: $host\ndate: $date\nGET $path HTTP/1.1';
    final sig = base64.encode(
      Hmac(sha256, utf8.encode(apiSecret))
          .convert(utf8.encode(signatureOrigin))
          .bytes,
    );
    final authOrigin =
        'api_key="$apiKey", algorithm="hmac-sha256", '
        'headers="host date request-line", signature="$sig"';
    final auth = base64.encode(utf8.encode(authOrigin));

    return 'wss://$host$path'
        '?authorization=${Uri.encodeComponent(auth)}'
        '&date=${Uri.encodeComponent(date)}'
        '&host=${Uri.encodeComponent(host)}';
  }

  String _httpDate(DateTime dt) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${wd[dt.weekday - 1]}, '
        '${dt.day.toString().padLeft(2, '0')} '
        '${mo[dt.month - 1]} '
        '${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')} GMT';
  }

  Future<AsrResult> transcribe(String filePath) async {
    try {
      // 读取 WAV 并定位 data chunk，取出原始 PCM
      final bytes = await File(filePath).readAsBytes();
      int dataOffset = 44;
      for (int i = 12; i < min(200, bytes.length - 8); i++) {
        if (bytes[i] == 0x64 &&
            bytes[i + 1] == 0x61 &&
            bytes[i + 2] == 0x74 &&
            bytes[i + 3] == 0x61) {
          dataOffset = i + 8;
          break;
        }
      }
      final pcm = Uint8List.fromList(bytes.sublist(dataOffset));

      final channel =
          WebSocketChannel.connect(Uri.parse(_buildSignedUrl()));
      final completer = Completer<AsrResult>();
      final Map<int, String> segments = {};

      channel.stream.listen(
        (msg) {
          try {
            final json =
                jsonDecode(msg as String) as Map<String, dynamic>;
            final header = json['header'] as Map<String, dynamic>?;
            final code = header?['code'] as int? ?? 0;
            final wsStatus = header?['status'] as int? ?? -1;

            if (code != 0) {
              channel.sink.close();
              if (!completer.isCompleted) {
                completer.complete(AsrResult(
                  code: code,
                  text: '',
                  error:
                      '讯飞错误 $code: ${header?['message'] ?? ''}',
                ));
              }
              return;
            }

            final payload =
                json['payload'] as Map<String, dynamic>?;
            final result =
                payload?['result'] as Map<String, dynamic>?;
            if (result != null) {
              final textB64 = result['text'] as String?;
              if (textB64 != null && textB64.isNotEmpty) {
                final decoded =
                    utf8.decode(base64.decode(textB64));
                final data =
                    jsonDecode(decoded) as Map<String, dynamic>;
                final sn = data['sn'] as int? ?? 0;
                final pgs = data['pgs'] as String? ?? 'apd';
                final ws = data['ws'] as List<dynamic>? ?? [];

                final segment = ws.map((w) {
                  final cw = (w as Map<String, dynamic>)['cw']
                          as List<dynamic>? ??
                      [];
                  return cw
                      .map((c) =>
                          (c as Map<String, dynamic>)['w']
                              as String? ??
                          '')
                      .join();
                }).join();

                if (pgs == 'rpl') {
                  final rg = data['rg'] as List<dynamic>?;
                  if (rg != null && rg.length >= 2) {
                    final from = rg[0] as int;
                    final to = rg[1] as int;
                    for (int i = from; i <= to; i++) {
                      segments.remove(i);
                    }
                  }
                }
                segments[sn] = segment;
              }
            }

            if (wsStatus == 2) {
              channel.sink.close();
              if (!completer.isCompleted) {
                final text = (segments.keys.toList()..sort())
                    .map((k) => segments[k]!)
                    .join();
                completer.complete(AsrResult(code: 0, text: text));
              }
            }
          } catch (_) {}
        },
        onError: (err) {
          if (!completer.isCompleted) {
            completer.complete(
              AsrResult(code: -1, text: '', error: err.toString()),
            );
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            final text = (segments.keys.toList()..sort())
                .map((k) => segments[k]!)
                .join();
            completer.complete(AsrResult(code: 0, text: text));
          }
        },
      );

      // 按 40ms 帧率发送音频 (1280 bytes = 40ms @ 16kHz/16bit/mono)
      const frameSize = 1280;
      int offset = 0;
      int seq = 0;

      while (offset < pcm.length) {
        final end = min(offset + frameSize, pcm.length);
        final chunk = pcm.sublist(offset, end);
        final isFirst = seq == 0;
        final isLast = end >= pcm.length;
        final status = isFirst ? 0 : (isLast ? 2 : 1);

        final frame = <String, dynamic>{
          'header': {'app_id': appId, 'status': status},
          'payload': {
            'audio': {
              'encoding': 'raw',
              'sample_rate': 16000,
              'channels': 1,
              'bit_depth': 16,
              'seq': seq + 1,
              'status': status,
              'audio': base64.encode(chunk),
            },
          },
        };

        if (isFirst) {
          frame['parameter'] = {
            'iat': {
              'domain': 'slm',
              'language': language,
              'accent': 'mandarin',
              'eos': 3000,
              'vinfo': 1,
              'result': {
                'encoding': 'utf8',
                'compress': 'raw',
                'format': 'json',
              },
            },
          };
        }

        channel.sink.add(jsonEncode(frame));

        if (!isLast) {
          await Future.delayed(const Duration(milliseconds: 40));
        }
        offset = end;
        seq++;
      }

      return await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () => const AsrResult(
          code: -1,
          text: '',
          error: '讯飞 ASR 请求超时',
        ),
      );
    } catch (e) {
      return AsrResult(code: -1, text: '', error: e.toString());
    }
  }
}
