import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/event.dart';
import 'device_store.dart';
import 'log_service.dart';
import 'tracking_service.dart';

/// Represents an action taken on an event notification.
class EventNotificationAction {
  final String eventId;
  final String action; // 'note', 'stop', or 'cancel'

  EventNotificationAction(this.eventId, this.action);
}

/// Top-level callback for notification actions - must be top-level for background execution.
@pragma('vm:entry-point')
Future<void> _onNotificationActionReceived(ReceivedAction receivedAction) async {
  try {
    final actionKey = receivedAction.buttonKeyPressed;
    if (actionKey.isEmpty) return;

    // Handle device status actions (silent, background)
    if (actionKey.startsWith('status_')) {
      await _handleDeviceStatusAction(actionKey);
      return;
    }

    // Handle event actions (opens app, emits to stream for UI to handle)
    if (actionKey.startsWith('event_')) {
      await _handleEventAction(actionKey);
      return;
    }
  } catch (e) {
    debugPrint('Error in notification action callback: $e');
  }
}

/// Handle device status change from notification action (W/L/C buttons).
Future<void> _handleDeviceStatusAction(String actionKey) async {
  final parts = actionKey.split('_');
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
  await NotificationService.instance.updateDeviceNotification(updatedDevice);

  // Emit event for UI refresh (only works if app is in foreground)
  NotificationService.instance._emitDeviceStatusChanged(deviceId);
}

/// Handle event action from notification (Note/Stop/Cancel buttons).
Future<void> _handleEventAction(String actionKey) async {
  final parts = actionKey.split('_');
  if (parts.length < 3) return;

  final action = parts[1]; // 'note', 'stop', or 'cancel'
  final eventId = parts.sublist(2).join('_'); // Handle event IDs with underscores

  // Emit event for UI to handle (show appropriate dialog)
  NotificationService.instance._emitEventAction(EventNotificationAction(eventId, action));
}

class NotificationService {
  static const _eventsChannelKey = 'active_events';
  static const _eventsChannelName = 'Active Events';

  static const _deviceChannelKey = 'device_status';
  static const _deviceChannelName = 'Device Status';

  static NotificationService? _instance;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  /// Stream controller for notifying UI of device status changes from notification actions.
  final _deviceStatusChangedController = StreamController<String>.broadcast();

  /// Stream controller for notifying UI of event actions from notification buttons.
  final _eventActionController = StreamController<EventNotificationAction>.broadcast();

  /// Stream that emits device IDs when their status is changed via notification action.
  Stream<String> get onDeviceStatusChanged => _deviceStatusChangedController.stream;

  /// Stream that emits event actions when notification buttons are pressed.
  Stream<EventNotificationAction> get onEventAction => _eventActionController.stream;

  NotificationService._();

  @pragma('vm:entry-point')
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  // Test-only method to reset the singleton state
  static void resetForTesting() {
    _instance = null;
  }

  /// Internal method to emit device status changed event (called from top-level callback)
  void _emitDeviceStatusChanged(String deviceId) {
    _deviceStatusChangedController.add(deviceId);
  }

  /// Internal method to emit event action (called from top-level callback)
  void _emitEventAction(EventNotificationAction action) {
    _eventActionController.add(action);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (_initCompleter != null) {
      // Wait for ongoing initialization to complete
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();
    try {
      await AwesomeNotifications().initialize(
        null, // Use default app icon
        [
          NotificationChannel(
            channelKey: _eventsChannelKey,
            channelName: _eventsChannelName,
            channelDescription: 'Persistent notifications for active events',
            importance: NotificationImportance.Low,
            playSound: false,
            enableVibration: false,
          ),
          NotificationChannel(
            channelKey: _deviceChannelKey,
            channelName: _deviceChannelName,
            channelDescription: 'Persistent notifications for device status with quick toggle buttons',
            importance: NotificationImportance.Low,
            playSound: false,
            enableVibration: false,
          ),
        ],
      );

      // Set up action listeners with top-level callback
      await AwesomeNotifications().setListeners(
        onActionReceivedMethod: _onNotificationActionReceived,
      );

      // Request notification permission
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      // Log error but don't crash - notifications are non-critical
      // ignore: avoid_print
      print('NotificationService initialization failed: $e');
      _initCompleter!.complete();
      _initialized = false;
    } finally {
      _initCompleter = null;
    }
  }

  // --- Event Notification Methods ---

  /// Generate a unique notification ID for an event based on its UUID.
  /// IDs start at 2000 to avoid conflicts with device notifications (1000+).
  int _eventNotificationId(String eventId) {
    return 2000 + eventId.hashCode.abs() % 100000;
  }

  /// Show or update a notification for an event with Note/Stop/Cancel action buttons.
  Future<void> updateEventNotification(Event event) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) return;
    }

    final notificationId = _eventNotificationId(event.id);

    // Calculate duration
    final now = DateTime.now().toUtc();
    final duration = now.difference(event.startEarliest);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final durationStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    final title = event.displayName;
    final body = 'Duration: $durationStr';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey: _eventsChannelKey,
        title: title,
        body: body,
        locked: true, // Makes it ongoing/persistent
        autoDismissible: false,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'event_note_${event.id}',
          label: 'Note',
          autoDismissible: false, // Keep notification visible
          actionType: ActionType.Default, // Opens app to show note dialog
        ),
        NotificationActionButton(
          key: 'event_stop_${event.id}',
          label: 'Stop',
          color: Colors.orange,
          autoDismissible: false, // Keep notification until actually stopped
          actionType: ActionType.Default, // Opens app to show stop dialog
        ),
        NotificationActionButton(
          key: 'event_cancel_${event.id}',
          label: 'Cancel',
          color: Colors.red,
          autoDismissible: false, // Keep notification until actually cancelled
          actionType: ActionType.Default, // Opens app to show cancel confirmation
        ),
      ],
    );
  }

  /// Cancel the notification for a specific event.
  Future<void> cancelEventNotification(String eventId) async {
    if (!_initialized) return;
    await AwesomeNotifications().cancel(_eventNotificationId(eventId));
  }

  /// Update notifications for all active events.
  Future<void> updateAllEventNotifications(List<Event> events) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) return;
    }

    for (final event in events) {
      await updateEventNotification(event);
    }
  }

  /// Cancel notifications for all events in the list.
  Future<void> cancelAllEventNotifications(List<Event> events) async {
    if (!_initialized) return;
    for (final event in events) {
      await cancelEventNotification(event.id);
    }
  }

  // --- Legacy method for backward compatibility (now calls updateAllEventNotifications) ---

  Future<void> updateNotification(List<Event> activeEvents) async {
    if (!_initialized) {
      await initialize();
      if (!_initialized) return;
    }

    if (activeEvents.isEmpty) {
      await cancelNotification();
      return;
    }

    // Update individual notifications for each event
    await updateAllEventNotifications(activeEvents);
  }

  Future<void> cancelNotification() async {
    if (!_initialized) return;
    // Cancel all event notifications on this channel
    await AwesomeNotifications().cancelNotificationsByChannelKey(_eventsChannelKey);
  }

  // --- Device Notification Methods ---

  /// Generate a unique notification ID for a device based on its UUID.
  /// Device IDs start at 1000 and event IDs start at 2000 to avoid conflicts.
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

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: notificationId,
        channelKey: _deviceChannelKey,
        title: title,
        locked: true, // Makes it ongoing/persistent
        autoDismissible: false,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'status_worn_${device.id}',
          label: 'W',
          color: Colors.orange,
          actionType: ActionType.SilentAction, // Execute in background without opening app
        ),
        NotificationActionButton(
          key: 'status_loose_${device.id}',
          label: 'L',
          color: Colors.grey,
          actionType: ActionType.SilentAction,
        ),
        NotificationActionButton(
          key: 'status_charging_${device.id}',
          label: 'C',
          color: Colors.green,
          actionType: ActionType.SilentAction,
        ),
      ],
    );
  }

  /// Cancel the notification for a specific device.
  Future<void> cancelDeviceNotification(String deviceId) async {
    if (!_initialized) return;
    await AwesomeNotifications().cancel(_deviceNotificationId(deviceId));
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

  /// Cancel notifications for all devices in the list.
  Future<void> cancelAllDeviceNotifications(List<Device> devices) async {
    if (!_initialized) return;
    for (final device in devices) {
      await cancelDeviceNotification(device.id);
    }
  }
}
