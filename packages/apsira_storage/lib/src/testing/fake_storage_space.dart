// From lyceum test/fakes/fake_storage_space.dart @ 9f4ff27, with freeBytes
// (D-APK-015).
import '../storage_space.dart';

/// Storage with set amounts free: [free] is what [appFreeBytes] answers and
/// [folderFree] what [freeBytes] answers, for any tree (null, the default,
/// is space that cannot be measured). [calls] counts the [appFreeBytes]
/// questions, [folders] records the trees asked about.
final class FakeStorageSpace implements StorageSpace {
  FakeStorageSpace({this.free, this.folderFree});

  /// What [appFreeBytes] answers.
  int? free;

  /// What [freeBytes] answers.
  int? folderFree;

  /// How many times [appFreeBytes] was asked.
  int calls = 0;

  /// Each tree [freeBytes] was asked about, in order.
  final List<String> folders = [];

  @override
  Future<int?> appFreeBytes() async {
    calls++;
    return free;
  }

  @override
  Future<int?> freeBytes(String treeUri) async {
    folders.add(treeUri);
    return folderFree;
  }
}
