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
      expect(logLine, contains('2024-01-15T22:00:00.000Z'));
    });

    test('logEventCancelled with time window includes both times', () async {
      final service = LogService.instance;
      final event = Event(
        id: 'test-event-id-2',
        type: EventType.walk,
        startEarliest: DateTime.utc(2024, 1, 15, 10, 0),
        startLatest: DateTime.utc(2024, 1, 15, 10, 30),
      );

      await service.logEventCancelled(event);

      final logLines = await service.getLogLines();
      final logLine = logLines.last;
      expect(logLine, contains('EVENT_CANCELLED'));
      expect(logLine, contains('2024-01-15T10:00:00.000Z..2024-01-15T10:30:00.000Z'));
    });

    test('logEventCancelled does not include stop time', () async {
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

      // Count tab-separated fields - should have 5 fields for cancelled events
      // (timestamp, event_type, id, type, startWindow)
      final fields = logLine.split('\t');
      expect(fields.length, 5);

      // Verify no stop window (EVENT_STOPPED would have 6 fields)
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

    test('logTrackingPaused creates TRACKING_PAUSED log entry', () async {
      final service = LogService.instance;

      await service.logTrackingPaused();

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('TRACKING_PAUSED'));
      
      // Verify format: timestamp\tTRACKING_PAUSED
      final fields = logLine.split('\t');
      expect(fields.length, 2);
      expect(fields[1], 'TRACKING_PAUSED');
    });

    test('logTrackingResumed creates TRACKING_RESUMED log entry', () async {
      final service = LogService.instance;

      await service.logTrackingResumed();

      final logLines = await service.getLogLines();
      expect(logLines.length, 1);

      final logLine = logLines.first;
      expect(logLine, contains('TRACKING_RESUMED'));
      
      // Verify format: timestamp\tTRACKING_RESUMED
      final fields = logLine.split('\t');
      expect(fields.length, 2);
      expect(fields[1], 'TRACKING_RESUMED');
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
        
        // Verify it's in UTC format
        expect(timestamp, contains('Z'));
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
      
      expect(logLines[0], contains('TRACKING_PAUSED'));
      expect(logLines[1], contains('TRACKING_RESUMED'));
      expect(logLines[2], contains('TRACKING_PAUSED'));
      expect(logLines[3], contains('TRACKING_RESUMED'));
    });
  });
}
