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
    for (final candidate in [
      '/opt/homebrew/bin/brew',
      '/usr/local/bin/brew',
    ]) {
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
        final result = await Process.run(
          py,
          ['-c', 'import funasr; import fastapi; import uvicorn'],
        );
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
    final packages = [
      'funasr',
      'fastapi',
      'uvicorn',
      'python-multipart',
    ];
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
  }) async {
    final python = await _findPythonWithFunasr();
    if (python == null) {
      onOutput('Error: 未找到安装了 funasr 的 Python，请先完成上面的 Python FunASR 安装步骤。');
      return false;
    }

    final scriptPath = await _resolveDownloadScript();
    final modelDir = await getModelDir();

    onOutput('> $python $scriptPath --model-dir $modelDir\n');

    try {
      final process = await Process.start(
        python,
        [scriptPath, '--model-dir', modelDir],
        environment: {'PYTHONUNBUFFERED': '1', 'PATH': _mergedPath},
      );

      process.stdout
          .transform(const SystemEncoding().decoder)
          .listen((data) => onOutput(data));
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) => onOutput(data));

      final exitCode = await process.exitCode;
      if (exitCode == 0) {
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
