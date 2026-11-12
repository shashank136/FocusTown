import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/platform/live_status.dart';
import 'package:focus_town/platform/native_live_status_sink.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('focus/liveStatus');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final status = LiveStatus(
    endsAt: DateTime.utc(2026, 11, 12, 10),
    title: 'hut',
    away: true,
  );

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('show sends the end time in milliseconds, the title and away', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return null;
    });
    await NativeLiveStatusSink().show(status);
    expect(seen!.method, 'show');
    expect(seen!.arguments, {
      'endsAtMs': status.endsAt.millisecondsSinceEpoch,
      'title': 'hut',
      'away': true,
    });
  });

  test('end sends end', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return null;
    });
    await NativeLiveStatusSink().end();
    expect(seen!.method, 'end');
  });

  test('no native side, or a native failure, is ignored', () async {
    await NativeLiveStatusSink().show(status); // MissingPluginException
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => throw PlatformException(code: 'boom'),
    );
    await NativeLiveStatusSink().show(status);
    await NativeLiveStatusSink().end();
  });
}
