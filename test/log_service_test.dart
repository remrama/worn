import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worn/models/event.dart';
import 'package:worn/services/log_service.dart';

void main() {
  group('LogService event cancellation', () {
    setUp(() async {
      // Clear shared preferences before each test
      SharedPreferences.setMockInitialValues({});
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
      expect(logLine, contains('In Bed'));
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
      
      // Count tab-separated fields - should have 6 fields for cancelled events
      // (timestamp, event_type, id, type, displayName, startWindow)
      final fields = logLine.split('\t');
      expect(fields.length, 6);
      
      // Verify no stop window (EVENT_STOPPED would have 7 fields)
      expect(logLine, isNot(contains('STOPPED')));
    });
  });
}
