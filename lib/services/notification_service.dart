import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/event.dart';

class NotificationService {
  static const _channelId = 'active_events';
  static const _channelName = 'Active Events';
  static const _notificationId = 1;
  
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _initializing = false;

  NotificationService._();

  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  // Test-only method to reset the singleton state
  static void resetForTesting() {
    _instance = null;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (_initializing) {
      // Wait for ongoing initialization to complete
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _initializing = true;
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      
      await _notifications.initialize(initSettings);

      // Create notification channel for Android 8.0+
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Persistent notifications for active events',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      _initialized = true;
    } catch (e) {
      // Log error but don't crash - notifications are non-critical
      // In production, consider using a logging service
      _initialized = false;
    } finally {
      _initializing = false;
    }
  }

  Future<void> updateNotification(List<Event> activeEvents) async {
    if (!_initialized) await initialize();

    if (activeEvents.isEmpty) {
      await cancelNotification();
      return;
    }

    final count = activeEvents.length;
    final title = count == 1 ? '1 active event' : '$count active events';
    
    // Calculate current time once for all events
    final now = DateTime.now().toUtc();
    final lines = activeEvents.map((e) {
      final duration = now.difference(e.startEarliest);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final durationStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      return '${e.displayName} ($durationStr)';
    }).toList();

    final bigTextStyle = BigTextStyleInformation(
      lines.join('\n'),
      contentTitle: title,
    );

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Persistent notifications for active events',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      styleInformation: bigTextStyle,
    );

    final details = NotificationDetails(android: androidDetails);

    // Show first event in collapsed view, all events in expanded view
    await _notifications.show(
      _notificationId,
      title,
      lines.first,
      details,
    );
  }

  Future<void> cancelNotification() async {
    if (!_initialized) return;
    await _notifications.cancel(_notificationId);
  }
}
