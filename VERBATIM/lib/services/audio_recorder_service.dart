import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AudioRecorderService {
  Process? _process;
  String? _currentPath;
  String? _recExecutable;
  final StringBuffer _stderrBuffer = StringBuffer();
  String? _lastError;
  bool _recording = false;

  Future<bool> hasPermission() async {
    try {
      _recExecutable = await _resolveRecExecutable();
      final available = _recExecutable != null;
      debugPrint(
        '[Recorder] rec command available: $available, path=$_recExecutable',
      );
      return available;
    } catch (e) {
      debugPrint('[Recorder] rec check error: $e');
      return false;
    }
  }

  Future<String> start() async {
    if (_recording) {
      await stop();
    }
    _lastError = null;
    _stderrBuffer.clear();

    final dir = await getTemporaryDirectory();
    // Ensure the directory exists
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final filePath = p.join(dir.path, 'verbatim_recording.wav');
    _currentPath = filePath;

    // Delete old file
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }

    debugPrint('[Recorder] Starting rec → $filePath');

    final executable = _recExecutable ?? await _resolveRecExecutable();
    if (executable == null) {
      throw Exception(
        '未找到 rec 命令。请安装 SoX（brew install sox）并确认 /opt/homebrew/bin 或 /usr/local/bin 在 PATH 中',
      );
    }
    _recExecutable = executable;

    // rec output.wav rate 16000 channels 1
    // Use rate/channels as effects instead of -r/-c flags to let SoX
    // record at native rate and resample, avoiding "can't set sample rate" errors.
    _process = await Process.start(executable, [
      '-q',
      '-b',
      '16',
      filePath,
      'rate',
      '16000',
      'channels',
      '1',
    ]);

    // Log stderr for debugging
    _process!.stderr
        .transform(const SystemEncoding().decoder)
        .listen((data) {
          _stderrBuffer.write(data);
          debugPrint('[rec stderr] $data');
        });

    _recording = true;
    debugPrint('[Recorder] Recording started via: $executable');
    return filePath;
  }

  Future<String?> stop() async {
    if (!_recording || _process == null) {
      debugPrint('[Recorder] Not recording');
      return null;
    }

    final path = _currentPath;
    debugPrint('[Recorder] Stopping rec...');

    // Send SIGINT to rec so it writes the WAV header and exits cleanly
    _process!.kill(ProcessSignal.sigint);

    // Wait for process to exit (max 5 seconds)
    try {
      final exitCode = await _process!.exitCode.timeout(
        const Duration(seconds: 5),
      );
      debugPrint('[Recorder] rec exit code: $exitCode');
      if (exitCode != 0) {
        _lastError = _buildRecorderError();
      }
    } catch (_) {
      debugPrint('[Recorder] rec did not exit, killing');
      _process!.kill(ProcessSignal.sigkill);
      _lastError = '录音进程未正常退出，请重试';
    }

    _process = null;
    _recording = false;

    // Allow file system to flush after process exit
    await Future.delayed(const Duration(milliseconds: 100));

    // Verify file
    // Minimum size: 44-byte WAV header + ~0.3s of 16-bit 16kHz mono audio = 9644 bytes
    const minFileSize = 9644;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        final estimatedDurationMs = ((size - 44) / 32000 * 1000).round();
        debugPrint(
          '[Recorder] File ready: $size bytes (~${estimatedDurationMs}ms audio)',
        );
        if (size > minFileSize) {
          _currentPath = null;
          return path;
        }
        debugPrint(
          '[Recorder] File too small: $size bytes (min=$minFileSize, ~0.3s)',
        );
        _lastError ??= _buildRecorderError();
      } else {
        debugPrint('[Recorder] File not found: $path');
        _lastError ??= _buildRecorderError();
      }
    }

    _currentPath = null;
    return null;
  }

  /// Validate WAV file header integrity.
  /// Returns null if valid, or an error description string if invalid.
  static Future<String?> validateWavFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return 'File does not exist';
    }
    final size = await file.length();
    if (size < 44) {
      return 'File too small for WAV header ($size bytes)';
    }
    final bytes = await file.openRead(0, 44).fold<List<int>>(
      [],
      (prev, chunk) => prev..addAll(chunk),
    );
    // Check RIFF header
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    if (riff != 'RIFF') {
      return 'Missing RIFF header (got: $riff)';
    }
    // Check WAVE format
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (wave != 'WAVE') {
      return 'Missing WAVE marker (got: $wave)';
    }
    // Check fmt chunk
    final fmt = String.fromCharCodes(bytes.sublist(12, 16));
    if (fmt != 'fmt ') {
      return 'Missing fmt chunk (got: $fmt)';
    }
    // Check PCM format (audio format == 1 at offset 20, little-endian uint16)
    final audioFormat = bytes[20] | (bytes[21] << 8);
    if (audioFormat != 1) {
      return 'Not PCM format (audioFormat=$audioFormat)';
    }
    return null;
  }

  bool get isRecording => _recording;

  void dispose() {
    if (_process != null) {
      _process!.kill(ProcessSignal.sigint);
      _process = null;
    }
    _recording = false;
  }

  String? get lastError => _lastError;

  Future<String?> _resolveRecExecutable() async {
    // 1) Check common Homebrew/MacPorts locations first (GUI apps often miss PATH).
    const commonPaths = [
      '/opt/homebrew/bin/rec',
      '/usr/local/bin/rec',
      '/opt/local/bin/rec',
    ];
    for (final path in commonPaths) {
      final f = File(path);
      if (await f.exists()) {
        return path;
      }
    }

    // 2) Fallback to PATH lookup with injected common binary directories.
    final currentPath = Platform.environment['PATH'] ?? '';
    const extraPath = '/opt/homebrew/bin:/usr/local/bin:/opt/local/bin';
    final mergedPath = currentPath.isEmpty ? extraPath : '$currentPath:$extraPath';
    try {
      final result = await Process.run(
        '/usr/bin/which',
        ['rec'],
        environment: {'PATH': mergedPath},
      );
      if (result.exitCode == 0) {
        final resolved = (result.stdout as String).trim();
        if (resolved.isNotEmpty) return resolved;
      }
    } catch (e) {
      debugPrint('[Recorder] which rec failed: $e');
    }
    return null;
  }

  String _buildRecorderError() {
    final raw = _stderrBuffer.toString().trim();
    final lower = raw.toLowerCase();
    if (lower.contains('no default audio device configured')) {
      return '系统未检测到可用麦克风设备，请检查输入设备设置';
    }
    if (lower.contains('permission denied') ||
        raw.contains('Operation not permitted')) {
      return '麦克风权限被拒绝，请在系统设置中允许 VERBATIM 使用麦克风';
    }
    if (raw.isNotEmpty) {
      final compact = raw.replaceAll('\n', ' ');
      return '录音失败: ${compact.length > 180 ? '${compact.substring(0, 180)}...' : compact}';
    }
    return '录音失败，请检查麦克风权限与设备状态';
  }
}
