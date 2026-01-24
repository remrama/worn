import 'package:flutter_test/flutter_test.dart';
import 'package:worn/models/event.dart';
import 'package:worn/models/event_template.dart';

void main() {
  group('EventTemplate model', () {
    test('creates with required fields and auto-generates id', () {
      final template = EventTemplate(type: EventType.walk);

      expect(template.type, EventType.walk);
      expect(template.customName, isNull);
      expect(template.id, isNotEmpty);
    });

    test('creates with custom name for other type', () {
      final template = EventTemplate(type: EventType.other, customName: 'Yoga');

      expect(template.type, EventType.other);
      expect(template.customName, 'Yoga');
    });

    test('copyWith preserves unchanged fields', () {
      final template = EventTemplate(
        type: EventType.workout,
        customName: null,
      );

      final updated = template.copyWith(type: EventType.run);

      expect(updated.id, template.id);
      expect(updated.type, EventType.run);
      expect(updated.customName, isNull);
    });

    test('toMap and fromMap roundtrip', () {
      final template = EventTemplate(
        type: EventType.swim,
        customName: null,
      );

      final map = template.toMap();
      final restored = EventTemplate.fromMap(map);

      expect(restored.id, template.id);
      expect(restored.type, template.type);
      expect(restored.customName, template.customName);
    });

    test('toMap and fromMap roundtrip with custom name', () {
      final template = EventTemplate(
        type: EventType.other,
        customName: 'Meditation',
      );

      final map = template.toMap();
      final restored = EventTemplate.fromMap(map);

      expect(restored.id, template.id);
      expect(restored.type, EventType.other);
      expect(restored.customName, 'Meditation');
    });

    test('displayName returns label for standard types', () {
      expect(EventTemplate(type: EventType.watchTv).displayName, 'Watch TV');
      expect(EventTemplate(type: EventType.inBed).displayName, 'In Bed');
      expect(
          EventTemplate(type: EventType.lightsOut).displayName, 'Lights Out');
      expect(EventTemplate(type: EventType.walk).displayName, 'Walk');
      expect(EventTemplate(type: EventType.run).displayName, 'Run');
      expect(EventTemplate(type: EventType.workout).displayName, 'Workout');
      expect(EventTemplate(type: EventType.swim).displayName, 'Swim');
    });

    test('displayName returns customName for other type', () {
      final template = EventTemplate(type: EventType.other, customName: 'Yoga');
      expect(template.displayName, 'Yoga');
    });

    test('displayName returns label when other type has no customName', () {
      final template = EventTemplate(type: EventType.other);
      expect(template.displayName, 'Other');
    });

    group('matchesEvent', () {
      test('matches event with same standard type', () {
        final template = EventTemplate(type: EventType.walk);
        final event = Event(type: EventType.walk);

        expect(template.matchesEvent(event), true);
      });

      test('does not match event with different type', () {
        final template = EventTemplate(type: EventType.walk);
        final event = Event(type: EventType.run);

        expect(template.matchesEvent(event), false);
      });

      test('matches event with same other type and customName', () {
        final template =
            EventTemplate(type: EventType.other, customName: 'Yoga');
        final event = Event(type: EventType.other, customName: 'Yoga');

        expect(template.matchesEvent(event), true);
      });

      test('does not match event with different customName', () {
        final template =
            EventTemplate(type: EventType.other, customName: 'Yoga');
        final event = Event(type: EventType.other, customName: 'Meditation');

        expect(template.matchesEvent(event), false);
      });

      test(
          'does not match other type event with null customName against named template',
          () {
        final template =
            EventTemplate(type: EventType.other, customName: 'Yoga');
        final event = Event(type: EventType.other, customName: null);

        expect(template.matchesEvent(event), false);
      });
    });
  });
}
