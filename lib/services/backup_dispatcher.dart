import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

/// The installed Dart wrapper registers Pigeon handlers but does not signal the
/// Android 0.10.9 worker waiting for them. Signal only after executeTask's
/// synchronous handler registration; the native worker deduplicates readiness.
void registerBackupBackgroundHandler(BackgroundTaskHandler handler) {
  Workmanager().executeTask(handler);
  if (defaultTargetPlatform == TargetPlatform.android) {
    unawaited(WorkmanagerHostApi()
        .notifyBackgroundChannelInitialized()
        .catchError((Object _) =>
            debugPrint('Background worker readiness signal failed')));
  }
}
