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
  final DateTime startTime;

  Event({
    String? id,
    required this.type,
    this.customName,
    DateTime? startTime,
  })  : id = id ?? const Uuid().v4(),
        startTime = startTime ?? DateTime.now().toUtc();

  Event copyWith({
    EventType? type,
    String? customName,
    DateTime? startTime,
  }) {
    return Event(
      id: id,
      type: type ?? this.type,
      customName: customName ?? this.customName,
      startTime: startTime ?? this.startTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'customName': customName,
      'startTime': startTime.toIso8601String(),
    };
  }

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'],
      type: EventType.values.byName(map['type']),
      customName: map['customName'],
      startTime: DateTime.parse(map['startTime']),
    );
  }

  String get displayName {
    if (type == EventType.other && customName != null) {
      return customName!;
    }
    return labelFor(type);
  }

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
