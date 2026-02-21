import 'package:flutter_test/flutter_test.dart';
import 'package:verbatim/widgets/status_indicator.dart';

void main() {
  test('AppStatus enum has expected values', () {
    expect(AppStatus.values.length, 5);
    expect(AppStatus.values, contains(AppStatus.idle));
    expect(AppStatus.values, contains(AppStatus.recording));
    expect(AppStatus.values, contains(AppStatus.processing));
    expect(AppStatus.values, contains(AppStatus.done));
    expect(AppStatus.values, contains(AppStatus.error));
  });
}
