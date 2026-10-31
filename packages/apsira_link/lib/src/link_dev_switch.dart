// The Dart name of the development-build switch (contract app-link.md §3.3,
// rulings R-2 and R-5).

/// The `<meta-data>` an app declares in its **dev source set only**:
///
/// ```xml
/// <application>
///   <meta-data android:name="com.apsiralabs.apsira_link.DEV_LINK" android:value="true" />
/// </application>
/// ```
///
/// The package's Kotlin selects the relaxed, package-name-only check only when
/// the app's own id ends in `.dev` **and** its merged manifest carries this
/// switch; either alone selects nothing. Dart never selects a trust mode: the
/// constant is here so an app's release-manifest test can prove the switch
/// absent from its release manifests.
const linkDevSwitch = 'com.apsiralabs.apsira_link.DEV_LINK';
