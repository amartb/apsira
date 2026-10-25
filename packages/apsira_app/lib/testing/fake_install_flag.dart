import '../src/install_flag.dart';

/// An [InstallFlag] in memory: no file, no I/O, so a widget test that reads
/// or sets one settles in fake time. [value] is the flag; a test may read or
/// set it directly.
final class FakeInstallFlag implements InstallFlag {
  FakeInstallFlag({this.path = 'fake/install_flag.json', bool set = false})
    : value = set;

  @override
  final String path;

  /// Whether the flag is set.
  bool value;

  @override
  Future<bool> isSet() async => value;

  @override
  Future<void> set() async => value = true;
}
