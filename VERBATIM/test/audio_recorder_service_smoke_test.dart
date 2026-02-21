import 'package:flutter_test/flutter_test.dart';
import 'package:verbatim/services/audio_recorder_service.dart';

void main() {
  test('AudioRecorderService can resolve rec executable', () async {
    final recorder = AudioRecorderService();
    final ok = await recorder.hasPermission();
    expect(ok, isTrue);
  });
}
