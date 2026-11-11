import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focus_town/domain/testing/fake_clock.dart';
import 'package:focus_town/platform/local_log.dart';
import 'package:focus_town/platform/platform_bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late FakeClock clock;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('log');
    clock = FakeClock(start: DateTime.utc(2026, 1, 2, 3, 4, 5));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a line starts with the wall time in ISO form', () {
    final log = LocalLog(File('${dir.path}/log.txt'), clock)..write('hello');
    expect(log.lines.single, '2026-01-02T03:04:05.000Z hello');
  });

  test('201 writes keep the last 200 and drop the first', () {
    final log = LocalLog(File('${dir.path}/log.txt'), clock);
    for (var i = 0; i < 201; i++) {
      log.write('m$i');
    }
    expect(log.lines, hasLength(200));
    expect(log.lines.first, endsWith('m1'));
    expect(log.lines.last, endsWith('m200'));
  });

  test('lines survive a restart', () async {
    final file = File('${dir.path}/log.txt');
    LocalLog(file, clock)
      ..write('one')
      ..write('two');
    final again = LocalLog(file, clock);
    await again.load();
    expect(again.lines, hasLength(2));
    expect(again.lines.last, endsWith('two'));
  });

  test('a missing directory never throws', () async {
    final log = LocalLog(File('${dir.path}/nope/deeper/log.txt'), clock);
    await log.load();
    log.write('still kept in memory');
    expect(log.lines, hasLength(1));
  });

  test('with no file it is memory only', () {
    final log = LocalLog(null, clock)..write('x');
    expect(log.lines, hasLength(1));
  });

  test('a malformed native event writes one line', () async {
    const method = MethodChannel('focus/lifecycle');
    const events = EventChannel('focus/lifecycle/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          ..setMockMethodCallHandler(method, (_) async => 1000)
          ..setMockStreamHandler(
            events,
            MockStreamHandler.inline(
              onListen: (args, sink) => sink.success('???'),
            ),
          );
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(method, null)
        ..setMockStreamHandler(events, null);
    });
    final log = LocalLog(null, clock);
    final p = await bootstrapPlatform(channel: method, log: log);
    p.source.events.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(log.lines, hasLength(1));
    expect(log.lines.single, contains('Malformed lifecycle event'));
  });
}
