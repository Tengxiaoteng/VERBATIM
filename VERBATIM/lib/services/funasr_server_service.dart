import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

enum FunasrServerStatus { stopped, starting, loadingModels, ready, error }

class _ModelDownloadSourceConfig {
  final String label;
  final String hub;
  final String? hfEndpoint;

  const _ModelDownloadSourceConfig({
    required this.label,
    required this.hub,
    this.hfEndpoint,
  });
}

class FunasrServerService {
  final ValueChanged<FunasrServerStatus> onStatusChanged;
  final ValueChanged<String?> onErrorChanged;
  final void Function(double progress, String label)? onDownloadProgress;

  FunasrServerStatus _status = FunasrServerStatus.stopped;
  String? _error;
  Process? _process;
  Timer? _healthTimer;
  int _port = 10095;
  double _downloadProgress = 0.0;

  FunasrServerStatus get status => _status;
  String? get error => _error;
  double get downloadProgress => _downloadProgress;

  FunasrServerService({
    required this.onStatusChanged,
    required this.onErrorChanged,
    this.onDownloadProgress,
  });

  void _setStatus(FunasrServerStatus s) {
    _status = s;
    onStatusChanged(s);
  }

  void _setError(String? e) {
    _error = e;
    onErrorChanged(e);
  }

  /// Extract the port number from a base URL like "http://localhost:10095".
  int _parsePort(String baseUrl) {
    try {
      final uri = Uri.parse(baseUrl);
      return uri.port != 0 ? uri.port : 10095;
    } catch (_) {
      return 10095;
    }
  }

  /// Check if the FunASR server is already responding on the target port.
  Future<bool> _isPortInUse() async {
    try {
      final resp = await http
          .get(Uri.parse('http://localhost:$_port/health'))
          .timeout(const Duration(seconds: 2));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Copy the bundled funasr_server.py to Application Support.
  Future<String> _resolveScriptPath() async {
    final dir = await getApplicationSupportDirectory();
    final dest = File(p.join(dir.path, 'funasr_server.py'));

    // Always overwrite to keep in sync with the bundled version.
    final data = await rootBundle.loadString('assets/funasr_server.py');
    await dest.writeAsString(data);
    return dest.path;
  }

  /// Returns the local models directory path (inside Application Support).
  Future<String> _resolveModelDir() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'models');
  }

  /// Find a python3 that has funasr, fastapi, and uvicorn installed.
  Future<String?> _resolvePythonExecutable() async {
    final candidates = <String>[
      '/opt/homebrew/bin/python3',
      '/usr/local/bin/python3',
      '/opt/local/bin/python3',
    ];

    // Also try conda base and named environments.
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty) {
      candidates.addAll([
        '$home/miniconda3/bin/python3',
        '$home/anaconda3/bin/python3',
        '$home/miniforge3/bin/python3',
        '$home/.conda/bin/python3',
      ]);

      // Scan conda envs directories for a python3 with funasr.
      for (final condaRoot in [
        '$home/miniconda3/envs',
        '$home/anaconda3/envs',
        '$home/miniforge3/envs',
      ]) {
        final envsDir = Directory(condaRoot);
        if (envsDir.existsSync()) {
          try {
            for (final entry in envsDir.listSync()) {
              if (entry is Directory) {
                final py = '${entry.path}/bin/python3';
                if (!candidates.contains(py)) {
                  candidates.add(py);
                }
              }
            }
          } catch (_) {}
        }
      }
    }

    // Try which python3 with enhanced PATH.
    final extraPath = '/opt/homebrew/bin:/usr/local/bin:/opt/local/bin';
    final sysPath = Platform.environment['PATH'] ?? '';
    final mergedPath = '$extraPath:$sysPath';

    try {
      final which = await Process.run(
        '/usr/bin/which',
        ['python3'],
        environment: {'PATH': mergedPath},
      );
      if (which.exitCode == 0) {
        final found = (which.stdout as String).trim();
        if (found.isNotEmpty && !candidates.contains(found)) {
          candidates.insert(0, found);
        }
      }
    } catch (_) {}

    for (final py in candidates) {
      if (!await File(py).exists()) continue;

      // Check that required packages are importable.
      try {
        final result = await Process.run(py, [
          '-c',
          'import funasr; import fastapi; import uvicorn',
        ]);
        if (result.exitCode == 0) return py;
      } catch (_) {}
    }

    return null;
  }

  /// Start the FunASR server process.
  Future<void> start({
    String baseUrl = 'http://localhost:10095',
    String modelDownloadSource = 'auto',
    String modelDownloadMirrorUrl = '',
  }) async {
    _port = _parsePort(baseUrl);
    final sourceConfig = _resolveModelDownloadConfig(
      source: modelDownloadSource,
      mirrorUrl: modelDownloadMirrorUrl,
    );
    debugPrint('[FunasrServer] Model source: ${sourceConfig.label}');
    if (sourceConfig.hfEndpoint != null) {
      debugPrint('[FunasrServer] HF endpoint: ${sourceConfig.hfEndpoint}');
    }

    // If a server is already running on this port, just mark ready.
    if (await _isPortInUse()) {
      debugPrint('[FunasrServer] Port $_port already in use, marking ready');
      _setError(null);
      _setStatus(FunasrServerStatus.ready);
      return;
    }

    _setError(null);
    _downloadProgress = 0.0;
    _setStatus(FunasrServerStatus.starting);

    // Resolve python executable.
    final python = await _resolvePythonExecutable();
    if (python == null) {
      _setError(
        '未找到安装了 funasr/fastapi/uvicorn 的 Python3。\n'
        '请先运行: pip3 install funasr fastapi uvicorn python-multipart',
      );
      _setStatus(FunasrServerStatus.error);
      return;
    }
    debugPrint('[FunasrServer] Using python: $python');

    // Extract script and resolve model directory.
    final scriptPath = await _resolveScriptPath();
    debugPrint('[FunasrServer] Script at: $scriptPath');
    final modelDir = await _resolveModelDir();
    debugPrint('[FunasrServer] Model dir: $modelDir');

    // Launch process.
    try {
      final args = <String>[
        scriptPath,
        '--port',
        '$_port',
        '--model-dir',
        modelDir,
        '--hub',
        sourceConfig.hub,
      ];
      if (sourceConfig.hfEndpoint != null) {
        args.addAll(['--hf-endpoint', sourceConfig.hfEndpoint!]);
      }
      final env = <String, String>{'PYTHONUNBUFFERED': '1'};
      if (sourceConfig.hfEndpoint != null) {
        env['HF_ENDPOINT'] = sourceConfig.hfEndpoint!;
      }
      _process = await Process.start(python, args, environment: env);
    } catch (e) {
      _setError('启动 Python 进程失败: $e');
      _setStatus(FunasrServerStatus.error);
      return;
    }

    // Monitor stdout for model loading status.
    _process!.stdout.transform(utf8.decoder).listen((data) {
      debugPrint('[FunasrServer/stdout] $data');
      if (data.contains('Loading ASR model')) {
        _setStatus(FunasrServerStatus.loadingModels);
      }
      if (data.contains('Model loaded')) {
        // Model is loaded; health check will confirm ready.
      }
    });

    _process!.stderr.transform(utf8.decoder).listen((data) {
      debugPrint('[FunasrServer/stderr] $data');
      // uvicorn logs to stderr by default; check for model loading there too.
      if (data.contains('Loading ASR model')) {
        _setStatus(FunasrServerStatus.loadingModels);
      }
      // Parse tqdm download progress: "Downloading [model.pt]:  14%|..."
      _parseDownloadProgress(data);
    });

    // Handle unexpected exit.
    _process!.exitCode.then((code) {
      debugPrint('[FunasrServer] Process exited with code $code');
      _process = null;
      _healthTimer?.cancel();
      if (_status != FunasrServerStatus.stopped) {
        _setError('FunASR 进程意外退出 (code: $code)');
        _setStatus(FunasrServerStatus.error);
      }
    });

    // Poll health endpoint until it responds (timeout 5 minutes).
    _startHealthPolling();
  }

  _ModelDownloadSourceConfig _resolveModelDownloadConfig({
    required String source,
    required String mirrorUrl,
  }) {
    switch (source) {
      case 'hf_official':
        return const _ModelDownloadSourceConfig(
          label: 'HuggingFace 官方',
          hub: 'hf',
        );
      case 'hf_mirror':
        return const _ModelDownloadSourceConfig(
          label: 'HuggingFace 镜像',
          hub: 'hf',
          hfEndpoint: 'https://hf-mirror.com',
        );
      case 'custom_hf_mirror':
        final endpoint = mirrorUrl.trim();
        if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
          return _ModelDownloadSourceConfig(
            label: '自定义 HuggingFace 镜像',
            hub: 'hf',
            hfEndpoint: endpoint,
          );
        }
        return const _ModelDownloadSourceConfig(
          label: 'ModelScope 默认源（自定义镜像无效，已回退）',
          hub: 'ms',
        );
      case 'auto':
      default:
        return const _ModelDownloadSourceConfig(
          label: 'ModelScope 默认源',
          hub: 'ms',
        );
    }
  }

  void _startHealthPolling() {
    var elapsed = 0;
    const interval = 2;
    const timeoutSec = 300; // 5 minutes

    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: interval), (
      timer,
    ) async {
      elapsed += interval;
      if (elapsed > timeoutSec) {
        timer.cancel();
        _setError('FunASR 启动超时（超过 5 分钟），请检查 Python 环境和模型下载');
        _setStatus(FunasrServerStatus.error);
        return;
      }

      if (await _isPortInUse()) {
        timer.cancel();
        _setError(null);
        _setStatus(FunasrServerStatus.ready);
        debugPrint('[FunasrServer] Health check passed, server ready');
      }
    });
  }

  /// Stop the FunASR server gracefully.
  Future<void> stop() async {
    _healthTimer?.cancel();
    _healthTimer = null;

    final proc = _process;
    if (proc == null) {
      _setStatus(FunasrServerStatus.stopped);
      return;
    }

    _setStatus(FunasrServerStatus.stopped);
    _process = null;

    // SIGTERM first.
    proc.kill(ProcessSignal.sigterm);

    // Wait up to 5 seconds, then SIGKILL.
    final exited = await proc.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        proc.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    debugPrint('[FunasrServer] Server stopped (exit: $exited)');
  }

  /// Parse tqdm-style download progress from stderr output.
  void _parseDownloadProgress(String raw) {
    // Strip ANSI escape codes (e.g. cursor-up \x1B[A used by tqdm).
    final clean = raw
        .replaceAll(RegExp(r'\x1B\[[0-9;]*[mABCDGHJKSTf]'), '')
        .trim();
    final pctMatch = RegExp(r'(\d+)%\|').firstMatch(clean);
    if (pctMatch == null) return;

    final pct = int.parse(pctMatch.group(1)!);
    _downloadProgress = pct / 100.0;

    // Build a short human-readable label.
    final sizeMatch = RegExp(
      r'\|\s*([\d.]+\s*\w+)/([\d.]+\s*\w+)',
    ).firstMatch(clean);
    final speedMatch = RegExp(r'([\d.]+\s*[kKMGT]?B/s)').firstMatch(clean);
    final label =
        '$pct%'
        '${sizeMatch != null ? ' · ${sizeMatch.group(1)}/${sizeMatch.group(2)}' : ''}'
        '${speedMatch != null ? ' · ${speedMatch.group(1)}' : ''}';

    onDownloadProgress?.call(_downloadProgress, label);
  }

  /// Clean up all resources.
  Future<void> dispose() async {
    _healthTimer?.cancel();
    _healthTimer = null;
    await stop();
  }
}
