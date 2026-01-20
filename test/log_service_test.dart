import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worn/models/device.dart';
import 'package:worn/models/event.dart';
import 'package:worn/services/log_service.dart';

void main() {
  group('LogService event cancellation', () {
    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
      // Reset the singleton to ensure clean state for each test
      LogService.resetForTesting();
    });

    test('logEventCancelled creates EVENT_CANCELLED log entry', () async {
      final service = LogService.instance;
      final event = Event(
        id: 'test-event-id',
        type: EventType.inBed,
        startEarliest: DateTime.utc(2024, 1, 15, 22, 0),
        startLatest: DateTime.utc(2024, 1, 15, 22, 30),
      );

      await service.logEventCancelled(event);

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('EVENT_CANCELLED'));
      expect(logLine, contains('test-event-id'));
      expect(logLine, contains('inBed'));
      // Cancelled events should not include any start window metadata
      expect(logLine, isNot(contains('earliest=')));
      expect(logLine, isNot(contains('latest=')));
    });

    test('logEventCancelled does not include start window or stop time', () async {
      final service = LogService.instance;
      final event = Event(
        type: EventType.workout,
        startEarliest: DateTime.utc(2024, 1, 15, 14, 0),
        startLatest: DateTime.utc(2024, 1, 15, 14, 0),
      );

      await service.logEventCancelled(event);

      final logLines = await service.getLogLines();
      final logLine = logLines.last;

      // Verify it's a cancellation
      expect(logLine, contains('EVENT_CANCELLED'));

      // Count tab-separated fields - should have 4 fields for cancelled events
      // (timestamp, EVENT_CANCELLED, id, type)
      final fields = logLine.split('\t');
      expect(fields.length, 4);

      // Verify no stop window
      expect(logLine, isNot(contains('STOPPED')));
    });
  });

  group('LogService tracking log methods', () {
    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
      // Reset the singleton to ensure clean state for each test
      LogService.resetForTesting();
    });

    test('logTrackingPaused creates GLOBAL_TRACKING off log entry', () async {
      final service = LogService.instance;

      await service.logTrackingPaused();

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('GLOBAL_TRACKING'));
      expect(logLine, contains('off'));

      // Verify format: timestamp\tGLOBAL_TRACKING\toff
      final fields = logLine.split('\t');
      expect(fields.length, 3);
      expect(fields[1], 'GLOBAL_TRACKING');
      expect(fields[2], 'off');
    });

    test('logTrackingResumed creates GLOBAL_TRACKING on log entry', () async {
      final service = LogService.instance;

      await service.logTrackingResumed();

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('GLOBAL_TRACKING'));
      expect(logLine, contains('on'));

      // Verify format: timestamp\tGLOBAL_TRACKING\ton
      final fields = logLine.split('\t');
      expect(fields.length, 3);
      expect(fields[1], 'GLOBAL_TRACKING');
      expect(fields[2], 'on');
    });

    test('tracking log entries include valid ISO 8601 timestamps', () async {
      final service = LogService.instance;

      await service.logTrackingPaused();
      await service.logTrackingResumed();

      final logLines = await service.getLogLines();
      expect(logLines.length, 2);

      for (final logLine in logLines) {
        final fields = logLine.split('\t');
        final timestamp = fields[0];

        // Verify timestamp can be parsed as DateTime
        expect(() => DateTime.parse(timestamp), returnsNormally);

        // Verify it includes timezone offset (e.g., +00:00 or -05:00)
        expect(timestamp, matches(RegExp(r'[+-]\d{2}:\d{2}$')));
      }
    });

    test('tracking log methods can be called multiple times', () async {
      final service = LogService.instance;

      await service.logTrackingPaused();
      await service.logTrackingResumed();
      await service.logTrackingPaused();
      await service.logTrackingResumed();

      final logLines = await service.getLogLines();
      expect(logLines.length, 4);

      expect(logLines[0], contains('GLOBAL_TRACKING\toff'));
      expect(logLines[1], contains('GLOBAL_TRACKING\ton'));
      expect(logLines[2], contains('GLOBAL_TRACKING\toff'));
      expect(logLines[3], contains('GLOBAL_TRACKING\ton'));
    });
  });

  group('LogService device update with effective time', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LogService.resetForTesting();
    });

    test('logDeviceUpdated without effectiveTime does not include effective field', () async {
      final service = LogService.instance;
      final oldDevice = Device(
        id: 'device-123',
        name: 'MyWatch',
        deviceType: DeviceType.watch,
        status: DeviceStatus.loose,
      );
      final newDevice = oldDevice.copyWith(status: DeviceStatus.worn);

      await service.logDeviceUpdated(oldDevice, newDevice);

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('DEVICE_UPDATED'));
      expect(logLine, contains('status=worn'));
      expect(logLine, isNot(contains('effective=')));
    });

    test('logDeviceUpdated with effectiveTime includes effective field', () async {
      final service = LogService.instance;
      final oldDevice = Device(
        id: 'device-456',
        name: 'MyRing',
        deviceType: DeviceType.ring,
        status: DeviceStatus.charging,
      );
      final newDevice = oldDevice.copyWith(status: DeviceStatus.worn);
      final effectiveTime = DateTime.utc(2024, 1, 15, 10, 30);

      await service.logDeviceUpdated(oldDevice, newDevice, effectiveTime: effectiveTime);

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('DEVICE_UPDATED'));
      expect(logLine, contains('status=worn'));
      expect(logLine, contains('effective=2024-01-15T10:30:00.000Z'));
    });

    test('logDeviceUpdated effective field appears after status change', () async {
      final service = LogService.instance;
      final oldDevice = Device(
        id: 'device-789',
        name: 'MyBand',
        deviceType: DeviceType.wristband,
        status: DeviceStatus.worn,
      );
      final newDevice = oldDevice.copyWith(status: DeviceStatus.loose);
      final effectiveTime = DateTime.utc(2024, 1, 15, 9, 0);

      await service.logDeviceUpdated(oldDevice, newDevice, effectiveTime: effectiveTime);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      // Verify format: status change comes before effective time
      final statusIndex = logLine.indexOf('status=loose');
      final effectiveIndex = logLine.indexOf('effective=');
      expect(statusIndex, lessThan(effectiveIndex));
    });
  });

  group('LogService time window formatting', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LogService.resetForTesting();
    });

    test('logEventStarted with same earliest/latest outputs single timestamp', () async {
      final service = LogService.instance;
      final time = DateTime.utc(2024, 1, 15, 10, 30);
      final event = Event(
        id: 'test-id',
        type: EventType.walk,
        startEarliest: time,
        startLatest: time,
      );

      await service.logEventStarted(event);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      // Should contain single timestamp, not earliest=/latest= format
      expect(logLine, isNot(contains('earliest=')));
      expect(logLine, isNot(contains('latest=')));
      // Should contain the timestamp directly after event type
      expect(logLine, contains('walk\t'));
    });

    test('logEventStarted with different earliest/latest outputs key=value pairs', () async {
      final service = LogService.instance;
      final event = Event(
        id: 'test-id',
        type: EventType.walk,
        startEarliest: DateTime.utc(2024, 1, 15, 10, 0),
        startLatest: DateTime.utc(2024, 1, 15, 10, 30),
      );

      await service.logEventStarted(event);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      // Should contain earliest= and latest= fields
      expect(logLine, contains('earliest='));
      expect(logLine, contains('latest='));
    });

    test('logEventStopped with time window outputs earliest/latest for stop time', () async {
      final service = LogService.instance;
      final event = Event(
        id: 'test-id',
        type: EventType.run,
        startEarliest: DateTime.utc(2024, 1, 15, 10, 0),
        startLatest: DateTime.utc(2024, 1, 15, 10, 0),
      );

      await service.logEventStopped(
        event,
        DateTime.utc(2024, 1, 15, 11, 0),
        DateTime.utc(2024, 1, 15, 11, 15),
      );

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      expect(logLine, contains('EVENT_STOPPED'));
      // Stop time should have earliest=/latest= since they differ
      expect(logLine, contains('earliest='));
      expect(logLine, contains('latest='));
    });
  });

  group('LogService note entry types', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      LogService.resetForTesting();
    });

    test('logNote without device or event creates GLOBAL_NOTE entry', () async {
      final service = LogService.instance;

      await service.logNote('Test global note');

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      expect(logLine, contains('GLOBAL_NOTE'));
      expect(logLine, contains('Test global note'));
      expect(logLine, isNot(contains('DEVICE_NOTE')));
      expect(logLine, isNot(contains('ACTIVITY_NOTE')));
    });

    test('logNote with device creates DEVICE_NOTE entry', () async {
      final service = LogService.instance;
      final device = Device(
        id: 'device-123',
        name: 'MyWatch',
        deviceType: DeviceType.watch,
      );

      await service.logNote('Device specific note', device: device);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      expect(logLine, contains('DEVICE_NOTE'));
      expect(logLine, contains('device-123'));
      expect(logLine, contains('MyWatch'));
      expect(logLine, contains('Device specific note'));
    });

    test('logNote with event creates ACTIVITY_NOTE entry', () async {
      final service = LogService.instance;
      final event = Event(
        id: 'event-456',
        type: EventType.walk,
      );

      await service.logNote('Event specific note', event: event);

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      expect(logLine, contains('ACTIVITY_NOTE'));
      expect(logLine, contains('event-456'));
      expect(logLine, contains('Walk'));
      expect(logLine, contains('Event specific note'));
    });

    test('logNote sanitizes tabs and newlines', () async {
      final service = LogService.instance;

      await service.logNote('Note with\ttab and\nnewline');

      final logLines = await service.getLogLines();
      final logLine = logLines.first;

      // Tabs and newlines should be replaced with spaces
      expect(logLine, contains('Note with tab and newline'));
      expect(logLine, isNot(contains('\t\t'))); // No double tabs from note content
    });
  });
}
