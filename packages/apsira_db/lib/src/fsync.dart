// From relay lib/data/db/opener.dart @ 09b28810 (`fsyncDirectory`), the copy
// LYCEUM's lib/data/db/restore_swap.dart @ 9f4ff27 holds too; VIATICUM's
// async `syncDirectoryToDisk` @ 78d38e0 is replaced by it (D-APK-018).
/// Making a directory's renames and removals durable. Plain Dart: no Flutter
/// import (AC-13.5).
library;

import 'dart:convert' show utf8;
import 'dart:ffi';
import 'dart:io';

/// Makes the renames and removals in a directory durable. The opener and
/// the swap call it after each such step; tests pass a recorder. A sync
/// that fails throws a [FileSystemException].
typedef SyncDirectory = void Function(Directory directory);

/// `fsync(2)` on [directory], so the renames and removals in it survive a
/// power loss: Dart's `dart:io` has no call for it, so it goes to the C
/// library through `dart:ffi` (as `sqlite3` does). Throws
/// [FileSystemException] when the directory cannot be opened or synced.
void fsyncDirectory(Directory directory) {
  final libc = _Libc.instance;
  final bytes = utf8.encode(directory.path);
  final path = libc.malloc(bytes.length + 1);
  if (path == nullptr) {
    throw FileSystemException('cannot sync directory', directory.path);
  }
  try {
    path.asTypedList(bytes.length + 1)
      ..setAll(0, bytes)
      ..[bytes.length] = 0;
    final fd = libc.open(path, _oRdonly, 0);
    if (fd < 0) {
      throw FileSystemException(
        'cannot open directory to sync it',
        directory.path,
        OSError('', libc.errno()),
      );
    }
    try {
      if (libc.fsync(fd) != 0) {
        throw FileSystemException(
          'cannot sync directory',
          directory.path,
          OSError('', libc.errno()),
        );
      }
    } finally {
      libc.close(fd);
    }
  } finally {
    libc.free(path);
  }
}

/// `O_RDONLY`, 0 on Linux and Android.
const int _oRdonly = 0;

/// The few C library calls [fsyncDirectory] makes, looked up once in the
/// process (bionic on Android, glibc on a Linux host).
final class _Libc {
  _Libc._(DynamicLibrary lib)
    : open = lib
          .lookupFunction<
            Int32 Function(Pointer<Uint8>, Int32, VarArgs<(Int32,)>),
            int Function(Pointer<Uint8>, int, int)
          >('open'),
      fsync = lib.lookupFunction<Int32 Function(Int32), int Function(int)>(
        'fsync',
      ),
      close = lib.lookupFunction<Int32 Function(Int32), int Function(int)>(
        'close',
      ),
      malloc = lib
          .lookupFunction<
            Pointer<Uint8> Function(IntPtr),
            Pointer<Uint8> Function(int)
          >('malloc'),
      free = lib
          .lookupFunction<
            Void Function(Pointer<Uint8>),
            void Function(Pointer<Uint8>)
          >('free'),
      _errno = lib
          .lookupFunction<Pointer<Int32> Function(), Pointer<Int32> Function()>(
            lib.providesSymbol('__errno_location')
                ? '__errno_location'
                : '__errno',
          );

  static final _Libc instance = _Libc._(DynamicLibrary.process());

  final int Function(Pointer<Uint8>, int, int) open;
  final int Function(int) fsync;
  final int Function(int) close;
  final Pointer<Uint8> Function(int) malloc;
  final void Function(Pointer<Uint8>) free;
  final Pointer<Int32> Function() _errno;

  /// The last error number; for the message only, as the VM may have
  /// changed it since the failing call.
  int errno() => _errno().value;
}

/// Flushes [file]'s bytes to the disk (`fsync` through `dart:io`).
void flushFile(File file) {
  final handle = file.openSync(mode: FileMode.append);
  try {
    handle.flushSync();
  } finally {
    handle.closeSync();
  }
}
