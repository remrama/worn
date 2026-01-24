import 'package:uuid/uuid.dart';
import 'event.dart';

/// A template for an event type that the user wants to track.
/// Unlike Event, this represents a persistent tracked event type
/// that can be started/stopped multiple times.
class EventTemplate {
  final String id;
  final EventType type;
  final String? customName; // For "other" type

  EventTemplate._({
    required this.id,
    required this.type,
    this.customName,
  });

  factory EventTemplate({
    String? id,
    required EventType type,
    String? customName,
  }) {
    return EventTemplate._(
      id: id ?? const Uuid().v4(),
      type: type,
      customName: customName,
    );
  }

  EventTemplate copyWith({
    EventType? type,
    String? customName,
  }) {
    return EventTemplate._(
      id: id,
      type: type ?? this.type,
      customName: customName ?? this.customName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'customName': customName,
    };
  }

  factory EventTemplate.fromMap(Map<String, dynamic> map) {
    return EventTemplate._(
      id: map['id'],
      type: EventType.values.byName(map['type']),
      customName: map['customName'],
    );
  }

  String get displayName {
    if (type == EventType.other && customName != null) {
      return customName!;
    }
    return Event.labelFor(type);
  }

  /// Check if this template matches an active event
  bool matchesEvent(Event event) {
    if (type != event.type) return false;
    if (type == EventType.other) {
      return customName == event.customName;
    }
    return true;
  }
}
