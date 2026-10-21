# assets/fonts

The fonts of the UX §2.3 type scale and the UX §8.1 query field, bundled
under the SIL Open Font License 1.1 and never fetched at runtime (D-041).
Family names in `pubspec.yaml` match `RelayFonts` in
`lib/app/theme/relay_typography.dart`.

| File | Family, weight | Source | Use |
|---|---|---|---|
| `ArchivoExpanded-400.ttf` | `ArchivoExpanded` 400 | `apsira-brand/06-fonts`, as supplied | Large titles, numerals, the wordmark (D-055) |
| `ArchivoExpanded-600.ttf` | `ArchivoExpanded` 600 | `apsira-brand/06-fonts`, as supplied | As above |
| `LICENSE-Archivo.txt` | — | `apsira-brand/06-fonts`, as supplied | The OFL of the Expanded cuts |
| `Archivo[wdth,wght].ttf` | `Archivo`, variable: `wght` 100–900, `wdth` 62–125 | google/fonts `ofl/archivo`, as supplied | Body text and every other style (D-055) |
| `OFL-Archivo.txt` | — | google/fonts `ofl/archivo/OFL.txt` | Its OFL |
| `JetBrainsMono[wght].ttf` | `JetBrainsMono`, variable: `wght` 100–800 | google/fonts `ofl/jetbrainsmono`, as supplied | The monospace query field (UX §8.1) |
| `OFL-JetBrainsMono.txt` | — | google/fonts `ofl/jetbrainsmono/OFL.txt` | Its OFL |

Every licence file is also bundled as an asset.

## Variable fonts

Normal-width Archivo's default instance is `wght` 600, so a style that left
the axis unset would render semi-bold. Every `Archivo` style therefore sets
`fontVariations` (`wght` = its weight, `wdth` 100) beside `fontWeight`, and
`pubspec.yaml` declares the one file at 400, 500, 600 and 700, the weights
the scale uses, so the font matcher always finds an exact weight and never
synthesises bold on top of the axis. The Expanded cuts are static files and
carry no variations.

The bundle stores bracketed file names URI-encoded (`Archivo%5Bwdth,wght%5D.ttf`),
under the same key `FontManifest.json` names; `rootBundle` takes the plain name.

## Updating

`SHA256SUMS` records each file's digest; `sha256sum -c SHA256SUMS` checks
them. No file is edited or re-exported: to update one, copy it again from
its source, as supplied, and refresh its digest. The google/fonts files were
fetched once, by the conductor, for P0-06d (ruling R-7).
`test/app/theme/relay_fonts_test.dart` proves each family is declared under
its style name, loads from the asset bundle, has the axes the scale needs,
and travels with its licence.
