import 'package:flutter_test/flutter_test.dart';
import 'package:worn/models/event.dart';

void main() {
  group('Event model', () {
    test('creates with required fields and auto-generates id and startTime',
        () {
      final event = Event(type: EventType.walk);

      expect(event.type, EventType.walk);
      expect(event.customName, isNull);
      expect(event.id, isNotEmpty);
      expect(event.startEarliest, isNotNull);
      expect(event.startLatest, isNotNull);
      expect(event.startEarliest, event.startLatest);
    });

    test('creates with custom name for other type', () {
      final event = Event(type: EventType.other, customName: 'Yoga');

      expect(event.type, EventType.other);
      expect(event.customName, 'Yoga');
    });

    test('creates with time window for retroactive events', () {
      final earliest = DateTime.utc(2024, 1, 15, 10, 0);
      final latest = DateTime.utc(2024, 1, 15, 10, 30);
      final event = Event(
        type: EventType.inBed,
        startEarliest: earliest,
        startLatest: latest,
      );

      expect(event.startEarliest, earliest);
      expect(event.startLatest, latest);
      expect(event.hasStartWindow, true);
    });

    test('hasStartWindow is false when times are equal', () {
      final time = DateTime.utc(2024, 1, 15, 10, 0);
      final event = Event(
        type: EventType.walk,
        startEarliest: time,
        startLatest: time,
      );

      expect(event.hasStartWindow, false);
    });

    test('copyWith preserves unchanged fields', () {
      final startEarliest = DateTime.utc(2024, 1, 15, 10, 0);
      final startLatest = DateTime.utc(2024, 1, 15, 10, 30);
      final event = Event(
        type: EventType.workout,
        customName: null,
        startEarliest: startEarliest,
        startLatest: startLatest,
      );

      final updated = event.copyWith(type: EventType.run);

      expect(updated.id, event.id);
      expect(updated.type, EventType.run);
      expect(updated.startEarliest, startEarliest);
      expect(updated.startLatest, startLatest);
    });

    test('toMap and fromMap roundtrip', () {
      final startEarliest = DateTime.utc(2024, 1, 15, 10, 0);
      final startLatest = DateTime.utc(2024, 1, 15, 10, 30);
      final event = Event(
        type: EventType.swim,
        customName: null,
        startEarliest: startEarliest,
        startLatest: startLatest,
      );

      final map = event.toMap();
      final restored = Event.fromMap(map);

      expect(restored.id, event.id);
      expect(restored.type, event.type);
      expect(restored.customName, event.customName);
      expect(restored.startEarliest, event.startEarliest);
      expect(restored.startLatest, event.startLatest);
    });

    test('toMap and fromMap roundtrip with custom name', () {
      final event = Event(
        type: EventType.other,
        customName: 'Meditation',
      );

      final map = event.toMap();
      final restored = Event.fromMap(map);

      expect(restored.id, event.id);
      expect(restored.type, EventType.other);
      expect(restored.customName, 'Meditation');
    });

    test('fromMap handles migration from old single startTime format', () {
      final oldMap = {
        'id': 'test-id',
        'type': 'walk',
        'customName': null,
        'startTime': '2024-01-15T10:30:00.000Z',
      };

      final event = Event.fromMap(oldMap);

      expect(event.id, 'test-id');
      expect(event.type, EventType.walk);
      expect(event.startEarliest, DateTime.utc(2024, 1, 15, 10, 30));
      expect(event.startLatest, DateTime.utc(2024, 1, 15, 10, 30));
      expect(event.hasStartWindow, false);
    });

    test('displayName returns label for standard types', () {
      expect(Event(type: EventType.watchTv).displayName, 'Watch TV');
      expect(Event(type: EventType.inBed).displayName, 'In Bed');
      expect(Event(type: EventType.lightsOut).displayName, 'Lights Out');
      expect(Event(type: EventType.walk).displayName, 'Walk');
      expect(Event(type: EventType.run).displayName, 'Run');
      expect(Event(type: EventType.workout).displayName, 'Workout');
      expect(Event(type: EventType.swim).displayName, 'Swim');
    });

    test('displayName returns customName for other type', () {
      final event = Event(type: EventType.other, customName: 'Yoga');
      expect(event.displayName, 'Yoga');
    });

    test('displayName returns label when other type has no customName', () {
      final event = Event(type: EventType.other);
      expect(event.displayName, 'Other');
    });

    test('type labels are readable', () {
      expect(Event.labelFor(EventType.watchTv), 'Watch TV');
      expect(Event.labelFor(EventType.inBed), 'In Bed');
      expect(Event.labelFor(EventType.lightsOut), 'Lights Out');
      expect(Event.labelFor(EventType.walk), 'Walk');
      expect(Event.labelFor(EventType.run), 'Run');
      expect(Event.labelFor(EventType.workout), 'Workout');
      expect(Event.labelFor(EventType.swim), 'Swim');
      expect(Event.labelFor(EventType.other), 'Other');
    });
  });
}
