import 'dart:io';

import 'package:focus_town/domain/clock.dart';

/// A small log kept on the device: the last [maxLines] lines, saved to [_file]
/// after every write. Logging never throws. With no file it is memory only.
class LocalLog {
  /// Creates a log that persists to [_file] (or nowhere when null).
  new(this._file, this._clock);

  /// How many lines are kept.
  static const maxLines = 200;

  final File? _file;
  final Clock _clock;
  final List<String> _lines = [];

  /// The kept lines, oldest first.
  List<String> get lines => List.unmodifiable(_lines);

  /// Reads the saved lines back (after a restart).
  Future<void> load() async {
    try {
      final file = _file;
      if (file == null || !file.existsSync()) return;
      final saved = file.readAsLinesSync().where((l) => l.isNotEmpty);
      _lines
        ..clear()
        ..addAll(
          saved.skip(saved.length > maxLines ? saved.length - maxLines : 0),
        );
    } on Object {
      // Logging must never throw.
    }
  }

  /// Adds a line with the current wall time.
  void write(String message) {
    final oneLine = message.replaceAll('\n', ' ');
    _lines.add('${_clock.nowWall().toIso8601String()} $oneLine');
    if (_lines.length > maxLines) _lines.removeAt(0);
    try {
      _file?.writeAsStringSync('${_lines.join('\n')}\n');
    } on Object {
      // Logging must never throw.
    }
  }
}
