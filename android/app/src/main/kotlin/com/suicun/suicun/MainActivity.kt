package com.suicun.suicun

import io.flutter.embedding.android.FlutterFragmentActivity

// Stage B: local_auth (biometric / device credential) requires
// FlutterFragmentActivity; plain FlutterActivity breaks it.
class MainActivity : FlutterFragmentActivity()
