// The apsira_link consumer proof: hello once at start, then the answer or
// why APSIRA is unavailable; a backup handed over through
// ApsiraBackupTarget (contract app-link.md §5.1); APSIRA's restore offer
// taken through the example's own confirmation and read back through the
// same target (§5.4, D-034). Without APSIRA it shows "unavailable:
// not_installed", the button says unavailable, and nothing else changes
// (§1).
import 'dart:async';
import 'dart:typed_data';

import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_core/system_clock.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:apsira_link/backup_target.dart';
import 'package:apsira_link/backups.dart';
import 'package:apsira_link/requests.dart';
import 'package:apsira_storage/apsira_storage.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';

/// The example's backup: a fixed 4 KiB payload.
final examplePayload = Uint8List.fromList(
  List<int>.generate(4096, (i) => i % 256),
);

void main() {
  const link = ChannelApsiraLink();
  final clock = SystemClock();
  runApp(
    ExampleApp(
      link: link,
      target: ApsiraBackupTarget(
        link: link,
        backups: const ChannelApsiraBackupLink(),
        appPackage: 'com.apsiralabs.apsira_link_example',
        clock: clock,
      ),
      requests: ChannelAppLinkRequests(),
      clock: clock,
    ),
  );
}

/// Shows what [link] answers to `hello`, backs [examplePayload] up to
/// [target] and offers APSIRA's restores from [requests].
class ExampleApp extends StatefulWidget {
  const ExampleApp({
    required this.link,
    required this.target,
    required this.requests,
    required this.clock,
    super.key,
  });

  final ApsiraLink link;
  final BackupTarget target;
  final AppLinkRequests requests;

  /// Names each backup by when it was made.
  final Clock clock;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  late final Future<Result<LinkHello, LinkFailure>> _hello = widget.link
      .hello();
  late final Future<BackupFolder?> _folder = widget.target.pickFolder();
  StreamSubscription<RestoreOffer>? _offers;
  String? _backup;
  List<String> _restore = const [];
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _offers = widget.requests.offers.listen(_confirm);
    unawaited(_takePending());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_offers?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_takePending());
  }

  Future<void> _takePending() async {
    final offer = await widget.requests.takePendingOffer();
    if (offer != null) await _confirm(offer);
  }

  Future<void> _backUp(BackupFolder folder) async {
    setState(() => _busy = true);
    final name =
        'apsira_link_example-${widget.clock.nowUtc().millisecondsSinceEpoch}'
        '.bin';
    final written = await widget.target.write(
      folder,
      name,
      Stream.value(examplePayload),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _backup = switch (written) {
        Ok(:final value) => 'backup: queued (${value.sizeBytes} bytes)',
        Err(failure: BackupTarget.storageFull) => 'backup: storage full',
        Err(failure: BackupTarget.exists) => 'backup: exists',
        Err() => 'backup: unavailable',
      };
    });
  }

  // The example's own confirmation; on yes, the restore reads the backup
  // through the same target, as from the app's own folder.
  Future<void> _confirm(RestoreOffer offer) async {
    // A first frame for the dialog when the offer was waiting at start.
    await WidgetsBinding.instance.endOfFrame;
    final context = _navigator.currentContext;
    if (context == null || !context.mounted) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from APSIRA?'),
        content: Text(
          '${offer.name} · ${offer.sizeBytes} bytes · made '
          '${offer.madeUtc.toIso8601String()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final folder = await _folder ?? await widget.target.pickFolder();
    final restored = folder == null
        ? const ['restore: unavailable']
        : await _read(folder, offer.name);
    if (mounted) setState(() => _restore = restored);
  }

  Future<List<String>> _read(BackupFolder folder, String name) async {
    final bytes = BytesBuilder(copy: false);
    try {
      await for (final piece in widget.target.read(folder, name)) {
        bytes.add(piece);
      }
    } on BackupTargetException catch (error) {
      return [
        error.failure == BackupTarget.missing
            ? 'restore: missing'
            : 'restore: unavailable',
      ];
    }
    final all = bytes.takeBytes();
    return [
      'restored ${all.length} bytes',
      'sha256 ${crypto.sha256.convert(all)}',
    ];
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'apsira_link example',
    navigatorKey: _navigator,
    home: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder(
              future: _hello,
              builder: (context, snapshot) => switch (snapshot.data) {
                null => const Text('hello: …'),
                Ok(value: final hello) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'hello: ${hello.version} · app ${hello.appVersion} · '
                      'locked ${hello.locked}',
                    ),
                    if (hello.devUnverified) const Text('dev link: unverified'),
                  ],
                ),
                Err(failure: LinkUnavailable(:final wire)) => Text(
                  'unavailable: $wire',
                ),
                Err(failure: LinkCallFailed(:final wire)) => Text(
                  'error: $wire',
                ),
              },
            ),
            FutureBuilder(
              future: _folder,
              builder: (context, snapshot) => switch (snapshot) {
                AsyncSnapshot(
                  connectionState: ConnectionState.done,
                  :final data?,
                ) =>
                  FilledButton(
                    onPressed: _busy ? null : () => _backUp(data),
                    child: const Text('Back up to APSIRA'),
                  ),
                AsyncSnapshot(connectionState: ConnectionState.done) =>
                  const FilledButton(
                    onPressed: null,
                    child: Text('Back up to APSIRA: unavailable'),
                  ),
                _ => const FilledButton(
                  onPressed: null,
                  child: Text('Back up to APSIRA: …'),
                ),
              },
            ),
            if (_backup case final backup?) Text(backup),
            for (final line in _restore) Text(line),
          ],
        ),
      ),
    ),
  );
}
