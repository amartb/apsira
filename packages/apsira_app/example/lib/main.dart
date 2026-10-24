// A minimal consumer of apsira_app: it reads the device zone through the
// zone channel into SystemClock at start, as every Apsira app's bootstrap
// does. Its debug build is the proof that the package's Android half
// compiles (task F1).
import 'package:apsira_app/apsira_app.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(ExampleApp(readZone: const ZoneChannel().zoneId));
}

/// The example app: reads the zone with [readZone] once, at start.
class ExampleApp extends StatefulWidget {
  const ExampleApp({required this.readZone, super.key});

  final Future<String> Function() readZone;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  String _status = 'Reading the zone';

  @override
  void initState() {
    super.initState();
    SystemClock.refreshZone(widget.readZone)
        .then(
          (_) => 'Zone ${const SystemClock().timeZoneName()}',
          onError: (Object e) => 'No zone: $e',
        )
        .then((status) {
          if (mounted) setState(() => _status = status);
        });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'apsira_app example',
    home: Scaffold(body: Center(child: Text(_status))),
  );
}
