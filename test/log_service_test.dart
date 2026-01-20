import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      // Cancelled events no longer include start window
      expect(logLine, isNot(contains('2024-01-15T22:00:00.000Z')));
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
}
