import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/device.dart';
import '../models/event.dart';
import 'device_store.dart';
import 'log_service.dart';
import 'tracking_service.dart';

/// Top-level handler for background notification responses.
/// Must be a top-level function for background execution.
@pragma('vm:entry-point')
void _handleBackgroundNotificationResponse(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance._processNotificationAction(response);
}

class NotificationService {
  static const _channelId = 'active_events';
  static const _channelName = 'Active Events';
  static const _notificationId = 1;

  static const _deviceChannelId = 'device_status';
  static const _deviceChannelName = 'Device Status';

  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  Completer<void>? _initCompleter;

  /// Stream controller for notifying UI of device status changes from notification actions.
  final _deviceStatusChangedController = StreamController<String>.broadcast();

  /// Stream that emits device IDs when their status is changed via notification action.
  Stream<String> get onDeviceStatusChanged => _deviceStatusChangedController.stream;

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
    if (_initCompleter != null) {
      // Wait for ongoing initialization to complete
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _processNotificationAction,
        onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotificationResponse,
      );

      // Create notification channel for active events
      const androidChannel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Persistent notifications for active events',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );

      // Create notification channel for device status
      const deviceChannel = AndroidNotificationChannel(
        _deviceChannelId,
        _deviceChannelName,
        description: 'Persistent notifications for device status with quick toggle buttons',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(androidChannel);
      await androidPlugin?.createNotificationChannel(deviceChannel);

      // Request notification permission on Android 13+ (API 33+)
      final permissionGranted = await androidPlugin?.requestNotificationsPermission();
      if (permissionGranted == false) {
        // ignore: avoid_print
        print('NotificationService: notification permission denied');
      }

      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      // Log error but don't crash - notifications are non-critical
      // ignore: avoid_print
      print('NotificationService initialization failed: $e');
      // Complete normally (not with error) so callers don't need to handle exceptions
      // The _initialized flag remains false, so notification operations will be skipped
      _initCompleter!.complete();
      _initialized = false;
    } finally {
      _initCompleter = null;
    }
  }

  Future<void> updateNotification(List<Event> activeEvents) async {
    if (!_initialized) {
      await initialize();
      // If initialization failed, _initialized remains false - skip notification
      if (!_initialized) return;
    }

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

  // --- Device Notification Methods ---

  /// Generate a unique notification ID for a device based on its UUID.
  /// IDs start at 1000 to avoid conflicts with the events notification (ID 1).
  int _deviceNotificationId(String deviceId) {
    return 1000 + deviceId.hashCode.abs() % 100000;
  }

  /// Show or update a notification for a device with W/L/C action buttons.
  /// Only shows notification if device is powered on.
  Future<void> updateDeviceNotification(Device device) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) return;
    }

    // Don't show notification for powered-off devices
    if (!device.isPoweredOn) {
      await cancelDeviceNotification(device.id);
      return;
    }

    final notificationId = _deviceNotificationId(device.id);
    final statusLabel = Device.statusLabel(device.status);
    final title = '${device.name} - $statusLabel';

    // Show location when worn, empty otherwise
    final body = device.status == DeviceStatus.worn
        ? Device.locationLabel(device.location)
        : '';

    // Create action buttons for W/L/C
    final actions = [
      AndroidNotificationAction(
        'status_worn_${device.id}',
        'W',
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        'status_loose_${device.id}',
        'L',
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        'status_charging_${device.id}',
        'C',
        showsUserInterface: false,
      ),
    ];

    final androidDetails = AndroidNotificationDetails(
      _deviceChannelId,
      _deviceChannelName,
      channelDescription: 'Persistent notifications for device status with quick toggle buttons',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      actions: actions,
    );

    final details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      notificationId,
      title,
      body,
      details,
    );
  }

  /// Cancel the notification for a specific device.
  Future<void> cancelDeviceNotification(String deviceId) async {
    if (!_initialized) return;
    await _notifications.cancel(_deviceNotificationId(deviceId));
  }

  /// Update notifications for all powered-on devices.
  /// Cancels notifications for devices that are powered off or not in the list.
  Future<void> updateAllDeviceNotifications(List<Device> devices) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) return;
    }

    for (final device in devices) {
      if (device.isPoweredOn) {
        await updateDeviceNotification(device);
      } else {
        await cancelDeviceNotification(device.id);
      }
    }
  }

  // --- Notification Action Processing ---

  /// Process a notification action response (W/L/C button tap).
  Future<void> _processNotificationAction(NotificationResponse response) async {
    final actionId = response.actionId;
    if (actionId == null || actionId.isEmpty) return;

    // Parse action ID format: status_worn_{deviceId}, status_loose_{deviceId}, status_charging_{deviceId}
    if (!actionId.startsWith('status_')) return;

    final parts = actionId.split('_');
    if (parts.length < 3) return;

    final statusStr = parts[1];
    final deviceId = parts.sublist(2).join('_'); // Handle device IDs with underscores

    DeviceStatus? newStatus;
    switch (statusStr) {
      case 'worn':
        newStatus = DeviceStatus.worn;
      case 'loose':
        newStatus = DeviceStatus.loose;
      case 'charging':
        newStatus = DeviceStatus.charging;
      default:
        return;
    }

    // Check if tracking is enabled - ignore actions when paused
    final isTracking = await TrackingService.instance.isTracking();
    if (!isTracking) return;

    // Load the device
    final devices = await DeviceStore.instance.getDevices();
    final device = devices.where((d) => d.id == deviceId).firstOrNull;
    if (device == null) return;

    // Skip if status is unchanged
    if (device.status == newStatus) return;

    // Update the device status
    final updatedDevice = device.copyWith(status: newStatus);
    await DeviceStore.instance.updateDevice(updatedDevice);
    await LogService.instance.logDeviceUpdated(device, updatedDevice);

    // Update the notification to reflect new status
    await updateDeviceNotification(updatedDevice);

    // Emit event for UI refresh
    _deviceStatusChangedController.add(deviceId);
  }
}
