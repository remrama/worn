import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum DeviceType {
  watch,
  ring,
  wristband,
  armband,
  chestStrap,
  headband,
  other,
}

enum DeviceLocation {
  // Non-body locations (top of dropdown)
  loose,
  charging,
  // Wrist locations
  leftWrist,
  rightWrist,
  // Ankle locations
  leftAnkle,
  rightAnkle,
  // Arm locations
  leftUpperArm,
  rightUpperArm,
  // Leg locations
  leftThigh,
  rightThigh,
  // Finger locations
  leftIndexFinger,
  leftMiddleFinger,
  leftRingFinger,
  leftPinkyFinger,
  leftThumb,
  rightIndexFinger,
  rightMiddleFinger,
  rightRingFinger,
  rightPinkyFinger,
  rightThumb,
  // Other body parts
  chest,
  waist,
  neck,
  head,
  other,
}

class Device {
  final String id;
  final String name;
  final DeviceType deviceType;
  final DeviceLocation location;
  final String? serialNumber;

  Device({
    String? id,
    required this.name,
    this.deviceType = DeviceType.watch,
    this.location = DeviceLocation.loose,
    this.serialNumber,
  }) : id = id ?? const Uuid().v4();

  Device copyWith({
    String? name,
    DeviceType? deviceType,
    DeviceLocation? location,
    String? serialNumber,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      location: location ?? this.location,
      serialNumber: serialNumber ?? this.serialNumber,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'deviceType': deviceType.name,
      'location': location.name,
      'serialNumber': serialNumber,
    };
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'],
      name: map['name'],
      deviceType: _parseDeviceType(map),
      location: _parseLocation(map),
      serialNumber: map['serialNumber'],
    );
  }

  /// Parse device type from map, defaulting to watch for old devices
  static DeviceType _parseDeviceType(Map<String, dynamic> map) {
    if (map.containsKey('deviceType')) {
      return DeviceType.values.byName(map['deviceType']);
    }
    return DeviceType.watch; // Default for migration
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

  static IconData iconFor(DeviceType type) {
    switch (type) {
      case DeviceType.watch:
        return Icons.watch;
      case DeviceType.ring:
        return Icons.circle_outlined;
      case DeviceType.wristband:
        return Icons.watch_outlined;
      case DeviceType.armband:
        return Icons.sports;
      case DeviceType.chestStrap:
        return Icons.favorite;
      case DeviceType.headband:
        return Icons.headset;
      case DeviceType.other:
        return Icons.devices_other;
    }
  }

  static String typeLabel(DeviceType type) {
    switch (type) {
      case DeviceType.watch:
        return 'Watch';
      case DeviceType.ring:
        return 'Ring';
      case DeviceType.wristband:
        return 'Wristband';
      case DeviceType.armband:
        return 'Armband';
      case DeviceType.chestStrap:
        return 'Chest Strap';
      case DeviceType.headband:
        return 'Headband';
      case DeviceType.other:
        return 'Other';
    }
  }

  static List<DeviceLocation> availableLocationsFor(DeviceType type) {
    const common = [DeviceLocation.loose, DeviceLocation.charging];
    switch (type) {
      case DeviceType.watch:
      case DeviceType.wristband:
        return [...common, DeviceLocation.leftWrist, DeviceLocation.rightWrist];
      case DeviceType.ring:
        return [
          ...common,
          DeviceLocation.leftIndexFinger,
          DeviceLocation.leftMiddleFinger,
          DeviceLocation.leftRingFinger,
          DeviceLocation.leftPinkyFinger,
          DeviceLocation.leftThumb,
          DeviceLocation.rightIndexFinger,
          DeviceLocation.rightMiddleFinger,
          DeviceLocation.rightRingFinger,
          DeviceLocation.rightPinkyFinger,
          DeviceLocation.rightThumb,
        ];
      case DeviceType.armband:
        return [
          ...common,
          DeviceLocation.leftUpperArm,
          DeviceLocation.rightUpperArm,
        ];
      case DeviceType.chestStrap:
        return [...common, DeviceLocation.chest];
      case DeviceType.headband:
        return [...common, DeviceLocation.head];
      case DeviceType.other:
        return DeviceLocation.values;
    }
  }

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
      case DeviceLocation.leftIndexFinger:
        return 'Left Index Finger';
      case DeviceLocation.leftMiddleFinger:
        return 'Left Middle Finger';
      case DeviceLocation.leftRingFinger:
        return 'Left Ring Finger';
      case DeviceLocation.leftPinkyFinger:
        return 'Left Pinky Finger';
      case DeviceLocation.leftThumb:
        return 'Left Thumb';
      case DeviceLocation.rightIndexFinger:
        return 'Right Index Finger';
      case DeviceLocation.rightMiddleFinger:
        return 'Right Middle Finger';
      case DeviceLocation.rightRingFinger:
        return 'Right Ring Finger';
      case DeviceLocation.rightPinkyFinger:
        return 'Right Pinky Finger';
      case DeviceLocation.rightThumb:
        return 'Right Thumb';
      case DeviceLocation.chest:
        return 'Chest';
      case DeviceLocation.waist:
        return 'Waist';
      case DeviceLocation.neck:
        return 'Neck';
      case DeviceLocation.head:
        return 'Head';
      case DeviceLocation.other:
        return 'Other';
    }
  }
}
