import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pubspec has version 1.0.0+1', () {
    final text = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(r'^version: 1\.0\.0\+1$', multiLine: true).hasMatch(text),
      isTrue,
    );
  });

  test('the privacy manifest declares no tracking and no collected data', () {
    final text = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    expect(text, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
    expect(
      text,
      contains('<key>NSPrivacyCollectedDataTypes</key>\n\t<array/>'),
    );
  });
}
