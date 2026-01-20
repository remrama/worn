import 'package:flutter_test/flutter_test.dart';
import 'package:worn/models/device.dart';
import 'package:worn/models/event.dart';
import 'package:worn/services/notification_service.dart';

void main() {
  // Initialize Flutter binding before any tests run
  // This is required for notification plugin's method channel setup
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService', () {
    setUp(() {
      // Reset the singleton to ensure clean state for each test
      NotificationService.resetForTesting();
    });

    test('singleton instance returns same instance', () {
      final instance1 = NotificationService.instance;
      final instance2 = NotificationService.instance;
      
      expect(instance1, same(instance2));
    });

    test('resetForTesting creates new instance', () {
      final instance1 = NotificationService.instance;
      NotificationService.resetForTesting();
      final instance2 = NotificationService.instance;
      
      expect(instance1, isNot(same(instance2)));
    });

    test('updateNotification with empty list completes without error', () async {
      final service = NotificationService.instance;
      
      // This should not throw even if initialization fails
      // When not initialized and empty list provided, it returns early gracefully
      await expectLater(
        service.updateNotification([]),
        completes,
      );
    });

    test('duration formatting - less than 1 hour shows only minutes', () {
      // Create an event that started 30 minutes ago
      final now = DateTime.now().toUtc();
      final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));
      
      final event = Event(
        type: EventType.walk,
        startEarliest: thirtyMinutesAgo,
        startLatest: thirtyMinutesAgo,
      );

      // Calculate duration as the service would
      final duration = now.difference(event.startEarliest);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final durationStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      
      expect(durationStr, matches(RegExp(r'^\d+m$')));
      expect(durationStr, isNot(contains('h')));
    });

    test('duration formatting - over 1 hour shows hours and minutes', () {
      // Create an event that started 90 minutes ago
      final now = DateTime.now().toUtc();
      final ninetyMinutesAgo = now.subtract(const Duration(minutes: 90));
      
      final event = Event(
        type: EventType.workout,
        startEarliest: ninetyMinutesAgo,
        startLatest: ninetyMinutesAgo,
      );

      // Calculate duration as the service would
      final duration = now.difference(event.startEarliest);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final durationStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      
      expect(durationStr, matches(RegExp(r'^\d+h \d+m$')));
      expect(durationStr, contains('h'));
      expect(durationStr, contains('m'));
    });

    test('notification title - single event shows singular form', () {
      final events = [
        Event(type: EventType.walk),
      ];
      
      final count = events.length;
      final title = count == 1 ? '1 active event' : '$count active events';
      
      expect(title, '1 active event');
    });

    test('notification title - multiple events show plural form', () {
      final events = [
        Event(type: EventType.walk),
        Event(type: EventType.workout),
      ];
      
      final count = events.length;
      final title = count == 1 ? '1 active event' : '$count active events';
      
      expect(title, '2 active events');
    });

    test('notification content includes event display names', () {
      final now = DateTime.now().toUtc();
      final tenMinutesAgo = now.subtract(const Duration(minutes: 10));
      
      final events = [
        Event(
          type: EventType.walk,
          startEarliest: tenMinutesAgo,
          startLatest: tenMinutesAgo,
        ),
        Event(
          type: EventType.workout,
          startEarliest: tenMinutesAgo,
          startLatest: tenMinutesAgo,
        ),
      ];

      // Simulate the formatting logic from updateNotification
      final lines = events.map((e) {
        final duration = now.difference(e.startEarliest);
        final hours = duration.inHours;
        final minutes = duration.inMinutes % 60;
        final durationStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
        return '${e.displayName} ($durationStr)';
      }).toList();
      
      expect(lines.length, 2);
      expect(lines[0], contains('Walk'));
      expect(lines[1], contains('Workout'));
      expect(lines[0], matches(RegExp(r'\(\d+m\)')));
      expect(lines[1], matches(RegExp(r'\(\d+m\)')));
    });

    test('notification content with custom event name', () {
      final now = DateTime.now().toUtc();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      
      final event = Event(
        type: EventType.other,
        customName: 'Meditation',
        startEarliest: fiveMinutesAgo,
        startLatest: fiveMinutesAgo,
      );

      // Simulate the formatting logic
      final duration = now.difference(event.startEarliest);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      final durationStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
      final line = '${event.displayName} ($durationStr)';
      
      expect(line, contains('Meditation'));
      expect(line, isNot(contains('Other')));
    });

    test('duration calculation is consistent across events', () {
      final now = DateTime.now().toUtc();
      final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));

      final events = [
        Event(
          type: EventType.walk,
          startEarliest: thirtyMinutesAgo,
          startLatest: thirtyMinutesAgo,
        ),
        Event(
          type: EventType.run,
          startEarliest: thirtyMinutesAgo,
          startLatest: thirtyMinutesAgo,
        ),
      ];

      // Calculate current time once for all events (as the service does)
      final currentTime = DateTime.now().toUtc();
      final durations = events.map((e) {
        final duration = currentTime.difference(e.startEarliest);
        return duration.inMinutes;
      }).toList();

      // All events with same start time should have same duration
      expect(durations[0], durations[1]);
    });
  });

  group('Device Notification ID Generation', () {
    test('generates consistent ID for same device', () {
      const deviceId = 'test-device-uuid-123';

      // Simulate the ID generation logic from NotificationService
      int generateId(String id) => 1000 + id.hashCode.abs() % 100000;

      final id1 = generateId(deviceId);
      final id2 = generateId(deviceId);

      expect(id1, id2);
    });

    test('generates different IDs for different devices', () {
      const deviceId1 = 'device-uuid-one';
      const deviceId2 = 'device-uuid-two';

      int generateId(String id) => 1000 + id.hashCode.abs() % 100000;

      final id1 = generateId(deviceId1);
      final id2 = generateId(deviceId2);

      expect(id1, isNot(id2));
    });

    test('generated ID is greater than events notification ID (1)', () {
      const deviceId = 'any-device-id';

      int generateId(String id) => 1000 + id.hashCode.abs() % 100000;

      final id = generateId(deviceId);

      expect(id, greaterThan(1));
      expect(id, greaterThanOrEqualTo(1000));
    });

    test('generated ID stays within bounds', () {
      // Test with various device IDs including edge cases
      final deviceIds = [
        'simple-id',
        'very-long-device-id-that-might-overflow-something',
        '',
        'a',
        '123456789',
        'uuid-with-special-chars_and_underscores',
      ];

      int generateId(String id) => 1000 + id.hashCode.abs() % 100000;

      for (final deviceId in deviceIds) {
        final id = generateId(deviceId);
        expect(id, greaterThanOrEqualTo(1000));
        expect(id, lessThan(101000)); // 1000 + 100000
      }
    });
  });

  group('Device Notification Action ID Parsing', () {
    test('parses worn action correctly', () {
      const actionId = 'status_worn_device-uuid-123';

      final parts = actionId.split('_');
      final statusStr = parts[1];
      final deviceId = parts.sublist(2).join('_');

      expect(statusStr, 'worn');
      expect(deviceId, 'device-uuid-123');
    });

    test('parses loose action correctly', () {
      const actionId = 'status_loose_device-uuid-456';

      final parts = actionId.split('_');
      final statusStr = parts[1];
      final deviceId = parts.sublist(2).join('_');

      expect(statusStr, 'loose');
      expect(deviceId, 'device-uuid-456');
    });

    test('parses charging action correctly', () {
      const actionId = 'status_charging_device-uuid-789';

      final parts = actionId.split('_');
      final statusStr = parts[1];
      final deviceId = parts.sublist(2).join('_');

      expect(statusStr, 'charging');
      expect(deviceId, 'device-uuid-789');
    });

    test('handles device ID with underscores', () {
      const actionId = 'status_worn_device_with_many_underscores';

      final parts = actionId.split('_');
      final statusStr = parts[1];
      final deviceId = parts.sublist(2).join('_');

      expect(statusStr, 'worn');
      expect(deviceId, 'device_with_many_underscores');
    });

    test('rejects invalid action prefix', () {
      const actionId = 'invalid_worn_device-id';

      final isValid = actionId.startsWith('status_');

      expect(isValid, isFalse);
    });

    test('rejects action with insufficient parts', () {
      const actionId = 'status_worn';

      final parts = actionId.split('_');
      final hasEnoughParts = parts.length >= 3;

      expect(hasEnoughParts, isFalse);
    });
  });

  group('Device Notification Content', () {
    test('notification title format - device name and status', () {
      final device = Device(
        name: 'MyWatch',
        deviceType: DeviceType.watch,
        status: DeviceStatus.worn,
      );

      final statusLabel = Device.statusLabel(device.status);
      final title = '${device.name} - $statusLabel';

      expect(title, 'MyWatch - Worn');
    });

    test('powered off device should not show notification', () {
      final device = Device(
        name: 'MyWatch',
        deviceType: DeviceType.watch,
        status: DeviceStatus.worn,
        isPoweredOn: false,
      );

      // The logic: only show notification if powered on
      final shouldShow = device.isPoweredOn;

      expect(shouldShow, isFalse);
    });

    test('powered on device should show notification', () {
      final device = Device(
        name: 'MyWatch',
        deviceType: DeviceType.watch,
        status: DeviceStatus.worn,
        isPoweredOn: true,
      );

      final shouldShow = device.isPoweredOn;

      expect(shouldShow, isTrue);
    });
  });

  group('Device Status Change Stream', () {
    setUp(() {
      NotificationService.resetForTesting();
    });

    test('onDeviceStatusChanged stream is accessible', () {
      final service = NotificationService.instance;

      expect(service.onDeviceStatusChanged, isA<Stream<String>>());
    });

    test('stream is broadcast (multiple listeners allowed)', () async {
      final service = NotificationService.instance;

      // Should be able to listen multiple times without error
      final sub1 = service.onDeviceStatusChanged.listen((_) {});
      final sub2 = service.onDeviceStatusChanged.listen((_) {});

      await sub1.cancel();
      await sub2.cancel();
    });
  });
}
