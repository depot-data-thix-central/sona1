import 'package:flutter/foundation.dart';

/// Push notifications facade.
///
/// Firebase/FCM has been removed from this project to support a 100% Supabase
/// backend. This service is intentionally a **no-op** placeholder so the rest of
/// the app can keep calling it without crashing.
///
/// When you are ready to re-enable push notifications with Supabase, typical
/// options are:
/// - OneSignal
/// - Expo push (via edge function)
/// - Custom APNs/FCM server with device tokens stored in Supabase
class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  bool _initialized = false;

  Future<void> initIfNeeded() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('PushNotificationService: disabled (Firebase removed).');
  }

  Future<void> onSignedIn({required String userId}) async {
    await initIfNeeded();
  }

  Future<void> onSignedOut() async {
    // no-op
  }
}
