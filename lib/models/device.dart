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

/// Device status: worn (on body), loose (off body), or charging
enum DeviceStatus {
  worn,
  loose,
  charging,
}

enum DeviceLocation {
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
  final DeviceStatus status;
  final DeviceLocation location;
  final String? serialNumber;
  final bool isPoweredOn;

  Device({
    String? id,
    required this.name,
    this.deviceType = DeviceType.watch,
    this.status = DeviceStatus.loose,
    DeviceLocation? location,
    this.serialNumber,
    this.isPoweredOn = true,
  }) : id = id ?? const Uuid().v4(),
       location = location ?? defaultLocationFor(deviceType);

  Device copyWith({
    String? name,
    DeviceType? deviceType,
    DeviceStatus? status,
    DeviceLocation? location,
    String? serialNumber,
    bool? isPoweredOn,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      deviceType: deviceType ?? this.deviceType,
      status: status ?? this.status,
      location: location ?? this.location,
      serialNumber: serialNumber ?? this.serialNumber,
      isPoweredOn: isPoweredOn ?? this.isPoweredOn,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'deviceType': deviceType.name,
      'status': status.name,
      'location': location.name,
      'serialNumber': serialNumber,
      'isPoweredOn': isPoweredOn,
    };
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    final deviceType = _parseDeviceType(map);
    final parsed = _parseStatusAndLocation(map, deviceType);
    return Device(
      id: map['id'],
      name: map['name'],
      deviceType: deviceType,
      status: parsed.$1,
      location: parsed.$2,
      serialNumber: map['serialNumber'],
      isPoweredOn: map['isPoweredOn'] ?? true,
    );
  }

  /// Parse device type from map, defaulting to watch for old devices
  static DeviceType _parseDeviceType(Map<String, dynamic> map) {
    if (map.containsKey('deviceType')) {
      return DeviceType.values.byName(map['deviceType']);
    }
    return DeviceType.watch; // Default for migration
  }

  /// Parse status and location from map, handling migration from old format
  static (DeviceStatus, DeviceLocation) _parseStatusAndLocation(
    Map<String, dynamic> map,
    DeviceType deviceType,
  ) {
    // Very old format: 'status' and 'placement' fields (no 'location' field)
    if (map.containsKey('placement')) {
      final oldStatus = map['status'] as String?;
      final placement = map['placement'] as String?;
      if (oldStatus == 'loose') {
        return (DeviceStatus.loose, defaultLocationFor(deviceType));
      }
      if (oldStatus == 'charging') {
        return (DeviceStatus.charging, defaultLocationFor(deviceType));
      }
      // If worn, use the placement as location
      if (placement != null) {
        return (DeviceStatus.worn, DeviceLocation.values.byName(placement));
      }
      return (DeviceStatus.loose, defaultLocationFor(deviceType));
    }

    // New format: separate 'status' and 'location' fields where location is a body part
    if (map.containsKey('status') && map.containsKey('location')) {
      final statusStr = map['status'] as String;
      final locStr = map['location'] as String;
      // Check if location is a body part (not 'loose' or 'charging')
      if (locStr != 'loose' && locStr != 'charging') {
        final status = DeviceStatus.values.byName(statusStr);
        final location = DeviceLocation.values.byName(locStr);
        return (status, location);
      }
    }

    // Old format migration: 'location' field contained loose/charging/bodyPart
    if (map.containsKey('location')) {
      final locStr = map['location'] as String;
      if (locStr == 'loose') {
        return (DeviceStatus.loose, defaultLocationFor(deviceType));
      }
      if (locStr == 'charging') {
        return (DeviceStatus.charging, defaultLocationFor(deviceType));
      }
      // It's a body location, so status is worn
      return (DeviceStatus.worn, DeviceLocation.values.byName(locStr));
    }

    return (DeviceStatus.loose, defaultLocationFor(deviceType));
  }

  /// Whether the device is currently being worn (on a body part)
  bool get isWorn => status == DeviceStatus.worn;

  /// Returns the default body location for a device type
  static DeviceLocation defaultLocationFor(DeviceType type) {
    switch (type) {
      case DeviceType.watch:
      case DeviceType.wristband:
        return DeviceLocation.leftWrist;
      case DeviceType.ring:
        return DeviceLocation.leftRingFinger;
      case DeviceType.armband:
        return DeviceLocation.leftUpperArm;
      case DeviceType.chestStrap:
        return DeviceLocation.chest;
      case DeviceType.headband:
        return DeviceLocation.head;
      case DeviceType.other:
        return DeviceLocation.other;
    }
  }

  static String statusLabel(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.worn:
        return 'Worn';
      case DeviceStatus.loose:
        return 'Loose';
      case DeviceStatus.charging:
        return 'Charging';
    }
  }

  static String statusShortLabel(DeviceStatus status) {
    switch (status) {
      case DeviceStatus.worn:
        return 'W';
      case DeviceStatus.loose:
        return 'L';
      case DeviceStatus.charging:
        return 'C';
    }
  }

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
    switch (type) {
      case DeviceType.watch:
      case DeviceType.wristband:
        return [DeviceLocation.leftWrist, DeviceLocation.rightWrist];
      case DeviceType.ring:
        return [
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
          DeviceLocation.leftUpperArm,
          DeviceLocation.rightUpperArm,
        ];
      case DeviceType.chestStrap:
        return [DeviceLocation.chest];
      case DeviceType.headband:
        return [DeviceLocation.head];
      case DeviceType.other:
        return DeviceLocation.values;
    }
  }

  static String locationLabel(DeviceLocation loc) {
    switch (loc) {
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
