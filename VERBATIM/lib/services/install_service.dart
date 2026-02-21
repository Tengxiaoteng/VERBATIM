import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DependencyStatus {
  final bool homebrewAvailable;
  final bool soxAvailable;
  final bool pythonAvailable;
  final bool funasrAvailable;
  final bool modelsDownloaded;

  const DependencyStatus({
    required this.homebrewAvailable,
    required this.soxAvailable,
    required this.pythonAvailable,
    required this.funasrAvailable,
    required this.modelsDownloaded,
  });

  bool get allReady => soxAvailable && funasrAvailable;
}

class InstallService {
  /// Merged PATH that includes common Homebrew/MacPorts locations.
  static String get _mergedPath {
    final sysPath = Platform.environment['PATH'] ?? '';
    const extra = '/opt/homebrew/bin:/usr/local/bin:/opt/local/bin';
    return sysPath.isEmpty ? extra : '$sysPath:$extra';
  }

  // ── Homebrew ──────────────────────────────────────────────────────

  Future<bool> checkHomebrew() async {
    try {
      final result = await Process.run(
        '/usr/bin/which',
        ['brew'],
        environment: {'PATH': _mergedPath},
      );
      return result.exitCode == 0 &&
          (result.stdout as String).trim().isNotEmpty;
    } catch (e) {
      debugPrint('[Install] checkHomebrew error: $e');
      return false;
    }
  }

  // ── SoX / rec ─────────────────────────────────────────────────────

  Future<bool> checkSox() async {
    // Check common Homebrew/MacPorts locations first.
    const commonPaths = [
      '/opt/homebrew/bin/rec',
      '/usr/local/bin/rec',
      '/opt/local/bin/rec',
    ];
    for (final path in commonPaths) {
      if (await File(path).exists()) return true;
    }

    // Fallback to PATH lookup.
    try {
      final result = await Process.run(
        '/usr/bin/which',
        ['rec'],
        environment: {'PATH': _mergedPath},
      );
      return result.exitCode == 0 &&
          (result.stdout as String).trim().isNotEmpty;
    } catch (e) {
      debugPrint('[Install] checkSox error: $e');
      return false;
    }
  }

  /// Install SoX via Homebrew. Streams output lines through [onOutput].
  /// Returns true on success.
  Future<bool> installSox({
    required void Function(String line) onOutput,
  }) async {
    // Resolve brew executable path.
    String? brewPath;
    for (final candidate in ['/opt/homebrew/bin/brew', '/usr/local/bin/brew']) {
      if (await File(candidate).exists()) {
        brewPath = candidate;
        break;
      }
    }
    if (brewPath == null) {
      try {
        final which = await Process.run(
          '/usr/bin/which',
          ['brew'],
          environment: {'PATH': _mergedPath},
        );
        if (which.exitCode == 0) {
          brewPath = (which.stdout as String).trim();
        }
      } catch (_) {}
    }
    if (brewPath == null || brewPath.isEmpty) {
      onOutput('Error: Homebrew not found. Please install Homebrew first.');
      onOutput('Visit https://brew.sh for installation instructions.');
      return false;
    }

    onOutput('> $brewPath install sox\n');

    try {
      final process = await Process.start(
        brewPath,
        ['install', 'sox'],
        environment: {'PATH': _mergedPath},
      );

      process.stdout
          .transform(const SystemEncoding().decoder)
          .listen((data) => onOutput(data));
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) => onOutput(data));

      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        onOutput('\nSoX installed successfully.');
        return true;
      } else {
        onOutput('\nbrew install sox failed (exit code: $exitCode)');
        return false;
      }
    } catch (e) {
      onOutput('\nError running brew: $e');
      return false;
    }
  }

  // ── Python / FunASR ───────────────────────────────────────────────

  /// Find a python3 executable (does not check for funasr packages).
  Future<String?> _findPython() async {
    final candidates = <String>[
      '/opt/homebrew/bin/python3',
      '/usr/local/bin/python3',
      '/opt/local/bin/python3',
    ];

    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty) {
      candidates.addAll([
        '$home/miniconda3/bin/python3',
        '$home/anaconda3/bin/python3',
        '$home/miniforge3/bin/python3',
        '$home/.conda/bin/python3',
      ]);
    }

    // which python3
    try {
      final which = await Process.run(
        '/usr/bin/which',
        ['python3'],
        environment: {'PATH': _mergedPath},
      );
      if (which.exitCode == 0) {
        final found = (which.stdout as String).trim();
        if (found.isNotEmpty && !candidates.contains(found)) {
          candidates.insert(0, found);
        }
      }
    } catch (_) {}

    for (final py in candidates) {
      if (await File(py).exists()) return py;
    }
    return null;
  }

  /// Check if a python3 with funasr+fastapi+uvicorn is available.
  Future<bool> checkPythonFunasr() async {
    final python = await _findPythonWithFunasr();
    return python != null;
  }

  /// Find python3 that has all required packages.
  Future<String?> _findPythonWithFunasr() async {
    final candidates = <String>[];

    final home = Platform.environment['HOME'] ?? '';
    // Standard locations
    candidates.addAll([
      '/opt/homebrew/bin/python3',
      '/usr/local/bin/python3',
      '/opt/local/bin/python3',
    ]);

    if (home.isNotEmpty) {
      candidates.addAll([
        '$home/miniconda3/bin/python3',
        '$home/anaconda3/bin/python3',
        '$home/miniforge3/bin/python3',
        '$home/.conda/bin/python3',
      ]);

      // Scan conda envs
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
                if (!candidates.contains(py)) candidates.add(py);
              }
            }
          } catch (_) {}
        }
      }
    }

    // which python3
    try {
      final which = await Process.run(
        '/usr/bin/which',
        ['python3'],
        environment: {'PATH': _mergedPath},
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

  /// Check if python3 is available (regardless of funasr).
  Future<bool> checkPython() async {
    return (await _findPython()) != null;
  }

  /// Install funasr + fastapi + uvicorn + python-multipart via pip3.
  /// Streams output through [onOutput]. Returns true on success.
  Future<bool> installFunasrEnv({
    required void Function(String line) onOutput,
  }) async {
    final python = await _findPython();
    if (python == null) {
      onOutput('Error: Python3 not found. Please install Python3 first.');
      return false;
    }

    // Use python -m pip to ensure we install into the correct environment.
    final packages = ['funasr', 'fastapi', 'uvicorn', 'python-multipart'];
    final args = ['-m', 'pip', 'install', ...packages];

    onOutput('> $python ${args.join(' ')}\n');

    try {
      final process = await Process.start(
        python,
        args,
        environment: {'PATH': _mergedPath},
      );

      process.stdout
          .transform(const SystemEncoding().decoder)
          .listen((data) => onOutput(data));
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) => onOutput(data));

      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        onOutput('\nPython dependencies installed successfully.');
        return true;
      } else {
        onOutput('\npip install failed (exit code: $exitCode)');
        return false;
      }
    } catch (e) {
      onOutput('\nError running pip: $e');
      return false;
    }
  }

  // ── Models ────────────────────────────────────────────────────────

  /// Returns the path to the local models directory inside Application Support.
  Future<String> getModelDir() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'models');
  }

  /// Returns true when the models sentinel file exists, meaning all models
  /// have been successfully downloaded to [getModelDir()].
  Future<bool> checkModelsDownloaded() async {
    try {
      final modelDir = await getModelDir();
      return File(p.join(modelDir, '.downloaded')).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Extract download_models.py from assets to Application Support.
  Future<String> _resolveDownloadScript() async {
    final dir = await getApplicationSupportDirectory();
    final dest = File(p.join(dir.path, 'download_models.py'));
    final data = await rootBundle.loadString('assets/download_models.py');
    await dest.writeAsString(data);
    return dest.path;
  }

  /// Download FunASR models to the local models directory.
  /// Requires Python with funasr installed.
  /// Streams output through [onOutput]. Returns true on success.
  Future<bool> downloadModels({
    required void Function(String line) onOutput,
    void Function(double progress, String label)? onProgress,
    String source = 'auto',
    String hfMirrorUrl = '',
  }) async {
    final python = await _findPythonWithFunasr();
    if (python == null) {
      onOutput('Error: 未找到安装了 funasr 的 Python，请先完成上面的 Python FunASR 安装步骤。');
      return false;
    }

    final scriptPath = await _resolveDownloadScript();
    final modelDir = await getModelDir();
    final sourceConfig = _resolveModelDownloadConfig(
      source: source,
      hfMirrorUrl: hfMirrorUrl,
    );
    if (!sourceConfig.valid) {
      onOutput('Error: ${sourceConfig.errorMessage}');
      return false;
    }

    final args = <String>[
      scriptPath,
      '--model-dir',
      modelDir,
      '--hub',
      sourceConfig.hub,
    ];
    if (sourceConfig.hfEndpoint != null) {
      args.addAll(['--hf-endpoint', sourceConfig.hfEndpoint!]);
    }
    final env = <String, String>{'PYTHONUNBUFFERED': '1', 'PATH': _mergedPath};
    if (sourceConfig.hfEndpoint != null) {
      env['HF_ENDPOINT'] = sourceConfig.hfEndpoint!;
    }

    onOutput(
      '[下载源] ${sourceConfig.label}'
      '${sourceConfig.hfEndpoint != null ? ' (${sourceConfig.hfEndpoint})' : ''}\n',
    );
    onOutput('> $python ${args.join(' ')}\n');

    try {
      final process = await Process.start(python, args, environment: env);

      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        onOutput(data);
        _parseDownloadProgressChunk(data, onProgress);
      });
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        onOutput(data);
        _parseDownloadProgressChunk(data, onProgress);
      });

      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        onProgress?.call(1.0, '100% · 下载完成');
        return true;
      } else {
        onOutput('\n模型下载失败 (exit code: $exitCode)');
        return false;
      }
    } catch (e) {
      onOutput('\n运行下载脚本失败: $e');
      return false;
    }
  }

  _ModelDownloadSourceConfig _resolveModelDownloadConfig({
    required String source,
    required String hfMirrorUrl,
  }) {
    switch (source) {
      case 'hf_official':
        return const _ModelDownloadSourceConfig(
          valid: true,
          label: 'HuggingFace 官方',
          hub: 'hf',
        );
      case 'hf_mirror':
        return const _ModelDownloadSourceConfig(
          valid: true,
          label: 'HuggingFace 镜像',
          hub: 'hf',
          hfEndpoint: 'https://hf-mirror.com',
        );
      case 'custom_hf_mirror':
        final endpoint = hfMirrorUrl.trim();
        if (endpoint.isEmpty) {
          return const _ModelDownloadSourceConfig(
            valid: false,
            label: '自定义镜像',
            hub: 'hf',
            errorMessage: '已选择自定义镜像，但镜像 URL 为空。',
          );
        }
        if (!endpoint.startsWith('http://') &&
            !endpoint.startsWith('https://')) {
          return const _ModelDownloadSourceConfig(
            valid: false,
            label: '自定义镜像',
            hub: 'hf',
            errorMessage: '镜像 URL 必须以 http:// 或 https:// 开头。',
          );
        }
        return _ModelDownloadSourceConfig(
          valid: true,
          label: '自定义 HuggingFace 镜像',
          hub: 'hf',
          hfEndpoint: endpoint,
        );
      case 'auto':
      default:
        return const _ModelDownloadSourceConfig(
          valid: true,
          label: 'ModelScope 默认源',
          hub: 'ms',
        );
    }
  }

  /// Parse tqdm-like model download progress from process output chunks.
  void _parseDownloadProgressChunk(
    String raw,
    void Function(double progress, String label)? onProgress,
  ) {
    if (onProgress == null) return;

    final clean = raw
        .replaceAll(RegExp(r'\x1B\[[0-9;]*[mABCDGHJKSTf]'), '')
        .trim();
    final pctMatch = RegExp(r'(\d+)%\|').firstMatch(clean);
    if (pctMatch == null) return;

    final pct = int.parse(pctMatch.group(1)!);
    final progress = pct.clamp(0, 100) / 100.0;

    final sizeMatch = RegExp(
      r'\|\s*([\d.]+\s*\w+)/([\d.]+\s*\w+)',
    ).firstMatch(clean);
    final speedMatch = RegExp(r'([\d.]+\s*[kKMGT]?B/s)').firstMatch(clean);
    final label =
        '$pct%'
        '${sizeMatch != null ? ' · ${sizeMatch.group(1)}/${sizeMatch.group(2)}' : ''}'
        '${speedMatch != null ? ' · ${speedMatch.group(1)}' : ''}';

    onProgress(progress, label);
  }

  // ── Check all ─────────────────────────────────────────────────────

  /// Checks all dependencies in parallel and returns a status snapshot.
  Future<DependencyStatus> checkAll() async {
    final results = await Future.wait([
      checkHomebrew(),
      checkSox(),
      checkPython(),
      checkPythonFunasr(),
      checkModelsDownloaded(),
    ]);

    return DependencyStatus(
      homebrewAvailable: results[0],
      soxAvailable: results[1],
      pythonAvailable: results[2],
      funasrAvailable: results[3],
      modelsDownloaded: results[4],
    );
  }
}

class _ModelDownloadSourceConfig {
  final bool valid;
  final String label;
  final String hub;
  final String? hfEndpoint;
  final String? errorMessage;

  const _ModelDownloadSourceConfig({
    required this.valid,
    required this.label,
    required this.hub,
    this.hfEndpoint,
    this.errorMessage,
  });
}
