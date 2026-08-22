package com.kasbills.kasbill;

import io.flutter.embedding.android.FlutterFragmentActivity;

/**
 * FlutterFragmentActivity (not FlutterActivity) is required by local_auth:
 * BiometricPrompt attaches to a FragmentActivity. App lock silently fails
 * without this.
 */
public class MainActivity extends FlutterFragmentActivity {
}
