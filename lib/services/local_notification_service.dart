// lib/services/local_notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;

class LocalNotificationService {
  static final LocalNotificationService instance = LocalNotificationService._();
  LocalNotificationService._();

  // 🌟 ASTUCE WEB : On type en 'dynamic' pour empêcher le compilateur dart2js 
  // de déclencher l'erreur "Too many positional arguments" sur le Web.
  final dynamic _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // 🌟 ASTUCE WEB : On bloque l'exécution native si on est sur navigateur
    if (kIsWeb) {
      _initialized = true;
      debugPrint('LocalNotificationService: Désactivé sur le Web');
      return;
    }

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('LocalNotification tapped → payload: ${details.payload}');
        // Ici tu pourras plus tard faire de la navigation avec go_router
      },
    );

    const channel = AndroidNotificationChannel(
      'thix_high_importance',
      'THIX Notifications',
      description: 'Notifications importantes de THIX ID',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
    debugPrint('LocalNotificationService: initialized');
  }

  Future<bool> requestPermission() async {
    // 🌟 On ignore la permission native sur le Web
    if (kIsWeb) return true;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await init();

    // 🌟 Sur le Web, on se contente d'afficher un log au lieu de planter
    if (kIsWeb) {
      debugPrint('🔔 [Web Notification] $title: $body');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'thix_high_importance',
      'THIX Notifications',
      channelDescription: 'Notifications importantes de THIX ID',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}
