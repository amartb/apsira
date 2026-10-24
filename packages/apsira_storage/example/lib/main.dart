// A minimal consumer of apsira_storage: it asks the storage channel for
// app storage's free space at start, as LYCEUM's restore and VIATICUM's
// photo import do. Its debug build is the proof that the package's Android
// half compiles (D-APK-015).
import 'package:apsira_storage/apsira_storage.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ExampleApp(space: ChannelStorageSpace()));
}

/// The example app: asks [space] for app storage's free bytes once, at
/// start.
class ExampleApp extends StatefulWidget {
  const ExampleApp({required this.space, super.key});

  final StorageSpace space;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  String _status = 'Measuring app storage';

  @override
  void initState() {
    super.initState();
    widget.space.appFreeBytes().then((free) {
      final status = free == null ? 'Free space unknown' : '$free bytes free';
      if (mounted) setState(() => _status = status);
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'apsira_storage example',
    home: Scaffold(body: Center(child: Text(_status))),
  );
}
