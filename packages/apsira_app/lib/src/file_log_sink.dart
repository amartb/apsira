// From relay lib/data/platform/file_log_sink.dart @ 09b28810, with the
// file's name and directory the app's (relay, viaticum, lyceum).
import 'dart:convert';
import 'dart:io';

import 'package:apsira_core/apsira_core.dart';

/// The rotating log file: at most [maxFiles] files of [maxBytes] each in
/// `<directory()>/logs/`, newest in `<name>.log`, then `<name>.1.log` up to
/// `<name>.<maxFiles - 1>.log`. Lines are stamped from the [Clock] port in
/// UTC; a record with a stack ends its line with `stackHash=<16 hex>` and
/// lists the frames indented below it.
///
/// Writes are synchronous appends, so a record is in the file before an
/// uncaught error can end the process.
final class FileLogSink implements LogSink {
  FileLogSink._(
    this._clock,
    this._dir,
    this._name, {
    required this.maxBytes,
    required this.maxFiles,
  }) : _size = _current(_dir, _name).existsSync()
           ? _current(_dir, _name).lengthSync()
           : 0;

  static const int defaultMaxFiles = 5;

  static const int defaultMaxBytes = 1024 * 1024;

  /// Opens the log in `<directory()>/logs/`, creating it, and continues the
  /// current file. [directory] is app-private storage
  /// (`getApplicationSupportDirectory`): never shared storage, never a
  /// backup folder. [name] is the app's, such as `relay`.
  static Future<FileLogSink> open(
    Clock clock, {
    required Future<Directory> Function() directory,
    required String name,
    int maxBytes = defaultMaxBytes,
    int maxFiles = defaultMaxFiles,
  }) async {
    final dir = Directory('${(await directory()).path}/logs');
    await dir.create(recursive: true);
    return FileLogSink._(
      clock,
      dir,
      name,
      maxBytes: maxBytes,
      maxFiles: maxFiles,
    );
  }

  final Clock _clock;
  final Directory _dir;
  final String _name;
  final int maxBytes;
  final int maxFiles;
  int _size;

  static File _current(Directory dir, String name) =>
      File('${dir.path}/$name.log');

  File _file(int index) => index == 0
      ? _current(_dir, _name)
      : File('${_dir.path}/$_name.$index.log');

  /// The log files that exist, oldest first, for the Diagnostics screen.
  List<File> files() => [
    for (var i = maxFiles - 1; i >= 0; i--)
      if (_file(i).existsSync()) _file(i),
  ];

  @override
  void write(LogRecord record) {
    final head = [
      _clock.nowUtc().toUtc().toIso8601String(),
      record.level.name.toUpperCase(),
      record.event,
      ...record.renderFields(),
    ].join(' ');
    final text = [
      head,
      for (final frame in record.stackFrames) '  $frame',
    ].map((line) => '$line\n').join();
    final bytes = utf8.encode(text);
    if (_size > 0 && _size + bytes.length > maxBytes) _rotate();
    _file(0).writeAsBytesSync(bytes, mode: FileMode.append);
    _size += bytes.length;
  }

  void _rotate() {
    final oldest = _file(maxFiles - 1);
    if (oldest.existsSync()) oldest.deleteSync();
    for (var i = maxFiles - 2; i >= 0; i--) {
      final file = _file(i);
      if (file.existsSync()) file.renameSync(_file(i + 1).path);
    }
    _size = 0;
  }
}
