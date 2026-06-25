package de.dispax.app

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth requires a FragmentActivity host to show the biometric prompt;
// the default FlutterActivity is not a FragmentActivity, so Face ID / fingerprint
// auth silently fails to display.
class MainActivity : FlutterFragmentActivity()
