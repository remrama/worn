import 'package:uuid/uuid.dart';

enum EventType {
  watchTv,
  inBed,
  lightsOut,
  walk,
  run,
  workout,
  swim,
  other,
}

class Event {
  final String id;
  final EventType type;
  final String? customName;
  final DateTime startEarliest;
  final DateTime startLatest;

  Event({
    String? id,
    required this.type,
    this.customName,
    DateTime? startEarliest,
    DateTime? startLatest,
  })  : id = id ?? const Uuid().v4(),
        startEarliest = startEarliest ?? DateTime.now().toUtc(),
        startLatest = startLatest ?? startEarliest ?? DateTime.now().toUtc();

  Event copyWith({
    EventType? type,
    String? customName,
    DateTime? startEarliest,
    DateTime? startLatest,
  }) {
    return Event(
      id: id,
      type: type ?? this.type,
      customName: customName ?? this.customName,
      startEarliest: startEarliest ?? this.startEarliest,
      startLatest: startLatest ?? this.startLatest,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'customName': customName,
      'startEarliest': startEarliest.toIso8601String(),
      'startLatest': startLatest.toIso8601String(),
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    // Handle migration from old single startTime format
    if (map.containsKey('startTime') && !map.containsKey('startEarliest')) {
      final startTime = DateTime.parse(map['startTime']);
      return Event(
        id: map['id'],
        type: EventType.values.byName(map['type']),
        customName: map['customName'],
        startEarliest: startTime,
        startLatest: startTime,
      );
    }
    return Event(
      id: map['id'],
      type: EventType.values.byName(map['type']),
      customName: map['customName'],
      startEarliest: DateTime.parse(map['startEarliest']),
      startLatest: DateTime.parse(map['startLatest']),
    );
  }

  String get displayName {
    if (type == EventType.other && customName != null) {
      return customName!;
    }
    return labelFor(type);
  }

  bool get hasStartWindow => startEarliest != startLatest;

  static String labelFor(EventType type) {
    switch (type) {
      case EventType.watchTv:
        return 'Watch TV';
      case EventType.inBed:
        return 'In Bed';
      case EventType.lightsOut:
        return 'Lights Out';
      case EventType.walk:
        return 'Walk';
      case EventType.run:
        return 'Run';
      case EventType.workout:
        return 'Workout';
      case EventType.swim:
        return 'Swim';
      case EventType.other:
        return 'Other';
    }
  }
}
