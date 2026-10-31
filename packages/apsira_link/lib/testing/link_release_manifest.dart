// The release-manifest check of the dev switch (contract app-link.md §3.3,
// rulings R-2 and R-5): what each app's release-manifest test calls on its
// `main` and release-flavour manifests to prove the switch absent.
import '../src/link_dev_switch.dart';

final _comment = RegExp(r'<!--.*?-->', dotAll: true);
final _metaData = RegExp(r'<meta-data\b([^>]*)>');

String? _attribute(String attributes, String name) {
  final match = RegExp(
    '\\b${RegExp.escape(name)}\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')',
  ).firstMatch(attributes);
  return match == null ? null : (match[1] ?? match[2]);
}

/// Whether [manifestXml] declares the [linkDevSwitch] `<meta-data>` with
/// `android:value="true"` outside a comment: the declaration that, with an
/// own id ending in `.dev`, selects the relaxed check. A release manifest
/// must answer `false`.
bool declaresLinkDevSwitch(String manifestXml) {
  final live = manifestXml.replaceAll(_comment, '');
  for (final element in _metaData.allMatches(live)) {
    final attributes = element[1]!;
    if (_attribute(attributes, 'android:name') == linkDevSwitch &&
        _attribute(attributes, 'android:value') == 'true') {
      return true;
    }
  }
  return false;
}
