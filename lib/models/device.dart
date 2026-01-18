import 'package:uuid/uuid.dart';

enum DeviceStatus { worn, loose, charging }

enum Placement { leftWrist, rightWrist, leftAnkle, rightAnkle, finger, other }

class Device {
  final String id;
  final String name;
  final Placement placement;
  final String? serialNumber;
  final DeviceStatus status;

  Device({
    String? id,
    required this.name,
    required this.placement,
    this.serialNumber,
    this.status = DeviceStatus.loose,
  }) : id = id ?? const Uuid().v4();

  Device copyWith({
    String? name,
    Placement? placement,
    String? serialNumber,
    DeviceStatus? status,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      placement: placement ?? this.placement,
      serialNumber: serialNumber ?? this.serialNumber,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'placement': placement.name,
      'serialNumber': serialNumber,
      'status': status.name,
    };
  }

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'],
      name: map['name'],
      placement: Placement.values.byName(map['placement']),
      serialNumber: map['serialNumber'],
      status: DeviceStatus.values.byName(map['status']),
    );
  }

  static String placementLabel(Placement p) {
    switch (p) {
      case Placement.leftWrist:
        return 'Left Wrist';
      case Placement.rightWrist:
        return 'Right Wrist';
      case Placement.leftAnkle:
        return 'Left Ankle';
      case Placement.rightAnkle:
        return 'Right Ankle';
      case Placement.finger:
        return 'Finger';
      case Placement.other:
        return 'Other';
    }
  }

  static String statusLabel(DeviceStatus s) {
    switch (s) {
      case DeviceStatus.worn:
        return 'Worn';
      case DeviceStatus.loose:
        return 'Loose';
      case DeviceStatus.charging:
        return 'Charging';
    }
  }
}
