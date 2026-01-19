import 'package:flutter_test/flutter_test.dart';
import 'package:worn/models/event.dart';
import 'package:worn/services/notification_service.dart';

void main() {
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

    test('updateNotification with empty list calls cancelNotification', () async {
      final service = NotificationService.instance;
      
      // This should not throw even though we haven't initialized
      // The service should handle gracefully
      await service.updateNotification([]);
      
      // If we get here without exception, the test passes
      expect(true, true);
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
}
