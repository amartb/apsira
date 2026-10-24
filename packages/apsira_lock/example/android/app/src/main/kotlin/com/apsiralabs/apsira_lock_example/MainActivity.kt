package com.apsiralabs.apsira_lock_example

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth's BiometricPrompt needs a FragmentActivity: every consumer of
// apsira_lock makes its MainActivity one (D-APK-016).
class MainActivity : FlutterFragmentActivity()
