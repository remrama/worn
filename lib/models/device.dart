import 'package:uuid/uuid.dart';

enum DeviceLocation {
  // Non-body locations (top of dropdown)
  loose,
  charging,
  // Body parts
  leftWrist,
  rightWrist,
  leftAnkle,
  rightAnkle,
  leftUpperArm,
  rightUpperArm,
  leftThigh,
  rightThigh,
  chest,
  waist,
  neck,
  head,
  finger,
  other,
}

class Device {
  final String id;
  final String name;
  final DeviceLocation location;
  final String? serialNumber;

  Device({
    String? id,
    required this.name,
    this.location = DeviceLocation.loose,
    this.serialNumber,
  }) : id = id ?? const Uuid().v4();

  Device copyWith({
    String? name,
    DeviceLocation? location,
    String? serialNumber,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      location: location ?? this.location,
      serialNumber: serialNumber ?? this.serialNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location.name,
      'serialNumber': serialNumber,
    };
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'],
      name: map['name'],
      location: _parseLocation(map),
      serialNumber: map['serialNumber'],
    );
  }

  /// Parse location from map, handling migration from old format
  static DeviceLocation _parseLocation(Map<String, dynamic> map) {
    // New format: single 'location' field
    if (map.containsKey('location')) {
      return DeviceLocation.values.byName(map['location']);
    }
    // Old format migration: combine 'status' and 'placement'
    final status = map['status'] as String?;
    final placement = map['placement'] as String?;
    if (status == 'loose') return DeviceLocation.loose;
    if (status == 'charging') return DeviceLocation.charging;
    // If worn, use the placement as location
    if (placement != null) {
      return DeviceLocation.values.byName(placement);
    }
    return DeviceLocation.loose;
  }

  /// Whether the device is currently being worn (on a body part)
  bool get isWorn =>
      location != DeviceLocation.loose && location != DeviceLocation.charging;

  static String locationLabel(DeviceLocation loc) {
    switch (loc) {
      case DeviceLocation.loose:
        return 'Loose';
      case DeviceLocation.charging:
        return 'Charging';
      case DeviceLocation.leftWrist:
        return 'Left Wrist';
      case DeviceLocation.rightWrist:
        return 'Right Wrist';
      case DeviceLocation.leftAnkle:
        return 'Left Ankle';
      case DeviceLocation.rightAnkle:
        return 'Right Ankle';
      case DeviceLocation.leftUpperArm:
        return 'Left Upper Arm';
      case DeviceLocation.rightUpperArm:
        return 'Right Upper Arm';
      case DeviceLocation.leftThigh:
        return 'Left Thigh';
      case DeviceLocation.rightThigh:
        return 'Right Thigh';
      case DeviceLocation.chest:
        return 'Chest';
      case DeviceLocation.waist:
        return 'Waist';
      case DeviceLocation.neck:
        return 'Neck';
      case DeviceLocation.head:
        return 'Head';
      case DeviceLocation.finger:
        return 'Finger';
      case DeviceLocation.other:
        return 'Other';
    }
  }
}
