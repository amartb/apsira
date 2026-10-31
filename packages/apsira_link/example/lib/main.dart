// The apsira_link consumer proof: hello once at start, then the answer or
// why APSIRA is unavailable. Without APSIRA it shows "unavailable:
// not_installed" and nothing else changes (contract app-link.md §1).
import 'package:apsira_core/apsira_core.dart';
import 'package:apsira_link/apsira_link.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp(link: ChannelApsiraLink()));

/// Shows what [link] answers to `hello`.
class ExampleApp extends StatefulWidget {
  const ExampleApp({required this.link, super.key});

  final ApsiraLink link;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final Future<Result<LinkHello, LinkFailure>> _hello = widget.link
      .hello();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'apsira_link example',
    home: Scaffold(
      body: Center(
        child: FutureBuilder(
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
            Err(failure: LinkCallFailed(:final wire)) => Text('error: $wire'),
          },
        ),
      ),
    ),
  );
}
