// From lyceum lib/features/settings/ui/about_page.dart @ 9f4ff27, with
// every string, the mark and the app's own rows passed in, and Material
// list tiles in place of LYCEUM's kit.
import 'package:apsira_ui/apsira_ui.dart';
import 'package:flutter/material.dart';

/// About: the app's mark, name and tagline in one card; the version, the
/// app's own [rows] (a tour replay, a privacy statement) and the
/// open-source licences in another (including the bundled fonts' OFL, which
/// `ApsiraBrand.registerLicences` adds at start-up); then the Apsira Labs
/// credit. The large title scrolls with the page.
class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    required this.title,
    required this.versionLabel,
    required this.licencesLabel,
    required this.appName,
    required this.version,
    required this.developedByLabel,
    required this.apsiraLabsLabel,
    this.tagline,
    this.mark,
    this.rows = const [],
  });

  /// The page's title (`About`).
  final String title;

  /// The version row's title; [version] is its value.
  final String versionLabel;

  /// The licences row's title.
  final String licencesLabel;

  /// The app's name, in the brand card and on the licence page.
  final String appName;

  final String version;

  /// The credit's line above the lockup (`Developed by`).
  final String developedByLabel;

  /// The lockup's semantic label (`Apsira Labs`).
  final String apsiraLabsLabel;

  final String? tagline;

  /// The app's mark, above its name.
  final Widget? mark;

  /// The app's own rows, between the version and the licences.
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final t = ApsiraTheme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ApsiraRadii.groupCard),
    );
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          ApsiraSpacing.screenGutter,
          0,
          ApsiraSpacing.screenGutter,
          ApsiraSpacing.largeTitleGutter,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: ApsiraSpacing.betweenCards),
            child: Text(title, style: ApsiraTypography.listTitle),
          ),
          Card(
            shape: shape,
            margin: const EdgeInsets.only(bottom: ApsiraSpacing.betweenCards),
            child: Padding(
              padding: ApsiraSpacing.cardHeader.copyWith(
                bottom: ApsiraSpacing.cardSide,
              ),
              child: Column(
                key: const Key('about/brand'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (mark case final mark?) ...[
                    mark,
                    const SizedBox(height: ApsiraSpacing.titleToMetaPills),
                  ],
                  Text(appName, style: ApsiraTypography.wordmark),
                  if (tagline case final tagline?)
                    Text(
                      tagline,
                      style: ApsiraTypography.meta.copyWith(color: t.ink2),
                    ),
                ],
              ),
            ),
          ),
          Card(
            shape: shape,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(title: Text(versionLabel), subtitle: Text(version)),
                ...rows,
                ListTile(
                  title: Text(licencesLabel),
                  trailing: const Icon(ApsiraIcons.chevron),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: appName,
                    applicationVersion: version,
                  ),
                ),
              ],
            ),
          ),
          _Credit(
            developedByLabel: developedByLabel,
            apsiraLabsLabel: apsiraLabsLabel,
          ),
        ],
      ),
    );
  }
}

/// "Developed by" and the Apsira Labs reversed lockup, as supplied and never
/// recoloured, on the dark ground in both themes: the lockup's reversed
/// colourway is made for a dark ground.
class _Credit extends StatelessWidget {
  const _Credit({
    required this.developedByLabel,
    required this.apsiraLabsLabel,
  });

  final String developedByLabel;
  final String apsiraLabsLabel;

  /// Above the brand's 160 px minimum for a horizontal lockup.
  static const _lockupWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    const dark = ApsiraTheme.dark;
    return Padding(
      padding: const EdgeInsets.only(top: ApsiraSpacing.betweenCards),
      child: DecoratedBox(
        key: const Key('about/credit'),
        decoration: BoxDecoration(
          color: dark.ground,
          borderRadius: BorderRadius.circular(ApsiraRadii.groupCard),
        ),
        child: Padding(
          padding: const EdgeInsets.all(ApsiraSpacing.largeTitleGutter),
          child: Column(
            children: [
              Text(
                developedByLabel,
                textAlign: TextAlign.center,
                style: ApsiraTypography.meta.copyWith(color: dark.ink3),
              ),
              const SizedBox(height: ApsiraSpacing.screenGutter),
              Image(
                image: ApsiraBrand.lockupReversed,
                width: _lockupWidth,
                semanticLabel: apsiraLabsLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
