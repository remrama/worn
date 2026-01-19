import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worn/models/device.dart';

void main() {
  group('Device model', () {
    test('creates with required fields and defaults to loose', () {
      final device = Device(name: 'Test Device');

      expect(device.name, 'Test Device');
      expect(device.location, DeviceLocation.loose);
      expect(device.serialNumber, isNull);
      expect(device.id, isNotEmpty);
    });

    test('creates with all fields', () {
      final device = Device(
        name: 'Full Device',
        location: DeviceLocation.rightWrist,
        serialNumber: 'SN123',
      );

      expect(device.name, 'Full Device');
      expect(device.location, DeviceLocation.rightWrist);
      expect(device.serialNumber, 'SN123');
    });

    test('copyWith preserves unchanged fields', () {
      final device = Device(
        name: 'Original',
        location: DeviceLocation.leftWrist,
        serialNumber: 'SN123',
      );

      final updated = device.copyWith(location: DeviceLocation.charging);

      expect(updated.id, device.id);
      expect(updated.name, 'Original');
      expect(updated.location, DeviceLocation.charging);
      expect(updated.serialNumber, 'SN123');
    });

    test('toMap and fromMap roundtrip', () {
      final device = Device(
        name: 'Roundtrip',
        location: DeviceLocation.leftIndexFinger,
        serialNumber: 'ABC',
      );

      final map = device.toMap();
      final restored = Device.fromMap(map);

      expect(restored.id, device.id);
      expect(restored.name, device.name);
      expect(restored.location, device.location);
      expect(restored.serialNumber, device.serialNumber);
      expect(restored.deviceType, device.deviceType);
    });

    test('fromMap handles old format migration', () {
      // Old format: loose status
      final looseMap = {
        'id': 'test-id-1',
        'name': 'Old Device',
        'placement': 'leftWrist',
        'serialNumber': null,
        'status': 'loose',
      };
      final looseDevice = Device.fromMap(looseMap);
      expect(looseDevice.location, DeviceLocation.loose);

      // Old format: charging status
      final chargingMap = {
        'id': 'test-id-2',
        'name': 'Charging Device',
        'placement': 'rightWrist',
        'serialNumber': null,
        'status': 'charging',
      };
      final chargingDevice = Device.fromMap(chargingMap);
      expect(chargingDevice.location, DeviceLocation.charging);

      // Old format: worn status (uses placement)
      final wornMap = {
        'id': 'test-id-3',
        'name': 'Worn Device',
        'placement': 'leftAnkle',
        'serialNumber': 'SN456',
        'status': 'worn',
      };
      final wornDevice = Device.fromMap(wornMap);
      expect(wornDevice.location, DeviceLocation.leftAnkle);
    });

    test('isWorn returns correct value', () {
      expect(Device(name: 'D1', location: DeviceLocation.loose).isWorn, false);
      expect(Device(name: 'D2', location: DeviceLocation.charging).isWorn, false);
      expect(Device(name: 'D3', location: DeviceLocation.leftWrist).isWorn, true);
      expect(Device(name: 'D4', location: DeviceLocation.chest).isWorn, true);
    });

    test('location labels are readable', () {
      expect(Device.locationLabel(DeviceLocation.loose), 'Loose');
      expect(Device.locationLabel(DeviceLocation.charging), 'Charging');
      expect(Device.locationLabel(DeviceLocation.leftWrist), 'Left Wrist');
      expect(Device.locationLabel(DeviceLocation.rightAnkle), 'Right Ankle');
      expect(Device.locationLabel(DeviceLocation.leftIndexFinger), 'Left Index Finger');
      expect(Device.locationLabel(DeviceLocation.chest), 'Chest');
    });

    test('iconFor returns correct icons for each device type', () {
      expect(Device.iconFor(DeviceType.watch), Icons.watch);
      expect(Device.iconFor(DeviceType.ring), Icons.circle_outlined);
      expect(Device.iconFor(DeviceType.wristband), Icons.watch_outlined);
      expect(Device.iconFor(DeviceType.armband), Icons.sports);
      expect(Device.iconFor(DeviceType.chestStrap), Icons.favorite);
      expect(Device.iconFor(DeviceType.headband), Icons.headset);
      expect(Device.iconFor(DeviceType.other), Icons.devices_other);
    });

    test('typeLabel returns correct labels for each device type', () {
      expect(Device.typeLabel(DeviceType.watch), 'Watch');
      expect(Device.typeLabel(DeviceType.ring), 'Ring');
      expect(Device.typeLabel(DeviceType.wristband), 'Wristband');
      expect(Device.typeLabel(DeviceType.armband), 'Armband');
      expect(Device.typeLabel(DeviceType.chestStrap), 'Chest Strap');
      expect(Device.typeLabel(DeviceType.headband), 'Headband');
      expect(Device.typeLabel(DeviceType.other), 'Other');
    });

    test('availableLocationsFor watch includes wrist locations', () {
      final locations = Device.availableLocationsFor(DeviceType.watch);
      expect(locations, contains(DeviceLocation.loose));
      expect(locations, contains(DeviceLocation.charging));
      expect(locations, contains(DeviceLocation.leftWrist));
      expect(locations, contains(DeviceLocation.rightWrist));
      expect(locations.length, 4);
    });

    test('availableLocationsFor wristband includes wrist locations', () {
      final locations = Device.availableLocationsFor(DeviceType.wristband);
      expect(locations, contains(DeviceLocation.loose));
      expect(locations, contains(DeviceLocation.charging));
      expect(locations, contains(DeviceLocation.leftWrist));
      expect(locations, contains(DeviceLocation.rightWrist));
      expect(locations.length, 4);
    });

    test('availableLocationsFor ring includes finger locations', () {
      final locations = Device.availableLocationsFor(DeviceType.ring);
      expect(locations, contains(DeviceLocation.loose));
      expect(locations, contains(DeviceLocation.charging));
      expect(locations, contains(DeviceLocation.leftIndexFinger));
      expect(locations, contains(DeviceLocation.leftMiddleFinger));
      expect(locations, contains(DeviceLocation.leftRingFinger));
      expect(locations, contains(DeviceLocation.leftPinkyFinger));
      expect(locations, contains(DeviceLocation.leftThumb));
      expect(locations, contains(DeviceLocation.rightIndexFinger));
      expect(locations, contains(DeviceLocation.rightMiddleFinger));
      expect(locations, contains(DeviceLocation.rightRingFinger));
      expect(locations, contains(DeviceLocation.rightPinkyFinger));
      expect(locations, contains(DeviceLocation.rightThumb));
      expect(locations.length, 12);
    });

    test('availableLocationsFor armband includes upper arm locations', () {
      final locations = Device.availableLocationsFor(DeviceType.armband);
      expect(locations, contains(DeviceLocation.loose));
      expect(locations, contains(DeviceLocation.charging));
      expect(locations, contains(DeviceLocation.leftUpperArm));
      expect(locations, contains(DeviceLocation.rightUpperArm));
      expect(locations.length, 4);
    });

    test('availableLocationsFor chestStrap includes chest location', () {
      final locations = Device.availableLocationsFor(DeviceType.chestStrap);
      expect(locations, contains(DeviceLocation.loose));
      expect(locations, contains(DeviceLocation.charging));
      expect(locations, contains(DeviceLocation.chest));
      expect(locations.length, 3);
    });

    test('availableLocationsFor headband includes head location', () {
      final locations = Device.availableLocationsFor(DeviceType.headband);
      expect(locations, contains(DeviceLocation.loose));
      expect(locations, contains(DeviceLocation.charging));
      expect(locations, contains(DeviceLocation.head));
      expect(locations.length, 3);
    });

    test('availableLocationsFor other includes all locations', () {
      final locations = Device.availableLocationsFor(DeviceType.other);
      expect(locations, equals(DeviceLocation.values));
    });
  });
}
