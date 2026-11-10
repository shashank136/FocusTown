import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/platform/testing/fake_notifier.dart';

void main() {
  test('records schedule and cancel calls in order', () async {
    final n = FakeNotifier();
    await n.scheduleAwayWarnings(passAvailable: true);
    await n.scheduleAwayWarnings(passAvailable: false);
    await n.cancelAwayWarnings();
    expect(n.calls, [
      'schedule(passAvailable: true)',
      'schedule(passAvailable: false)',
      'cancel',
    ]);
  });

  test('hasPermission follows the flag', () async {
    final n = FakeNotifier();
    expect(await n.hasPermission(), isFalse);
    n.permissionGranted = true;
    expect(await n.hasPermission(), isTrue);
  });

  test(
    'requestPermission is recorded and grants when the fake grants',
    () async {
      final n = FakeNotifier();
      expect(await n.requestPermission(), isTrue);
      expect(n.calls, ['requestPermission']);
      expect(await n.hasPermission(), isTrue);
    },
  );

  test(
    'requestPermission leaves permission off when the fake refuses',
    () async {
      final n = FakeNotifier(grants: false);
      expect(await n.requestPermission(), isFalse);
      expect(await n.hasPermission(), isFalse);
    },
  );
}
