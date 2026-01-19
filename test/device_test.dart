import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worn/models/device.dart';

void main() {
  group('Device model', () {
    test('creates with required fields and defaults to loose status', () {
      final device = Device(name: 'Test Device');

      expect(device.name, 'Test Device');
      expect(device.status, DeviceStatus.loose);
      expect(device.location, DeviceLocation.leftWrist); // Default for watch
      expect(device.serialNumber, isNull);
      expect(device.id, isNotEmpty);
      expect(device.isPoweredOn, true);
    });

    test('creates with all fields', () {
      final device = Device(
        name: 'Full Device',
        status: DeviceStatus.worn,
        location: DeviceLocation.rightWrist,
        serialNumber: 'SN123',
        isPoweredOn: false,
      );

      expect(device.name, 'Full Device');
      expect(device.status, DeviceStatus.worn);
      expect(device.location, DeviceLocation.rightWrist);
      expect(device.serialNumber, 'SN123');
      expect(device.isPoweredOn, false);
    });

    test('copyWith preserves unchanged fields', () {
      final device = Device(
        name: 'Original',
        status: DeviceStatus.worn,
        location: DeviceLocation.leftWrist,
        serialNumber: 'SN123',
        isPoweredOn: false,
      );

      final updated = device.copyWith(status: DeviceStatus.charging);

      expect(updated.id, device.id);
      expect(updated.name, 'Original');
      expect(updated.status, DeviceStatus.charging);
      expect(updated.location, DeviceLocation.leftWrist);
      expect(updated.serialNumber, 'SN123');
      expect(updated.isPoweredOn, false);
    });

    test('copyWith can change isPoweredOn', () {
      final device = Device(name: 'Test', isPoweredOn: true);
      final updated = device.copyWith(isPoweredOn: false);

      expect(updated.id, device.id);
      expect(updated.name, device.name);
      expect(updated.isPoweredOn, false);
    });

    test('toMap and fromMap roundtrip', () {
      final device = Device(
        name: 'Roundtrip',
        status: DeviceStatus.worn,
        location: DeviceLocation.leftIndexFinger,
        serialNumber: 'ABC',
        isPoweredOn: false,
        deviceType: DeviceType.ring,
      );

      final map = device.toMap();
      final restored = Device.fromMap(map);

      expect(restored.id, device.id);
      expect(restored.name, device.name);
      expect(restored.status, device.status);
      expect(restored.location, device.location);
      expect(restored.serialNumber, device.serialNumber);
      expect(restored.deviceType, device.deviceType);
      expect(restored.isPoweredOn, device.isPoweredOn);
    });

    test('fromMap handles old format migration (location field with loose/charging)', () {
      // Old format: location was 'loose'
      final looseMap = {
        'id': 'test-id-1',
        'name': 'Old Device',
        'deviceType': 'watch',
        'location': 'loose',
        'serialNumber': null,
      };
      final looseDevice = Device.fromMap(looseMap);
      expect(looseDevice.status, DeviceStatus.loose);
      expect(looseDevice.location, DeviceLocation.leftWrist); // default for watch

      // Old format: location was 'charging'
      final chargingMap = {
        'id': 'test-id-2',
        'name': 'Charging Device',
        'deviceType': 'watch',
        'location': 'charging',
        'serialNumber': null,
      };
      final chargingDevice = Device.fromMap(chargingMap);
      expect(chargingDevice.status, DeviceStatus.charging);

      // Old format: location was body part (means worn)
      final wornMap = {
        'id': 'test-id-3',
        'name': 'Worn Device',
        'deviceType': 'watch',
        'location': 'leftWrist',
        'serialNumber': 'SN456',
      };
      final wornDevice = Device.fromMap(wornMap);
      expect(wornDevice.status, DeviceStatus.worn);
      expect(wornDevice.location, DeviceLocation.leftWrist);
    });

    test('fromMap handles very old format migration (status + placement fields)', () {
      // Very old format: separate status and placement
      final looseMap = {
        'id': 'test-id-1',
        'name': 'Old Device',
        'placement': 'leftWrist',
        'serialNumber': null,
        'status': 'loose',
      };
      final looseDevice = Device.fromMap(looseMap);
      expect(looseDevice.status, DeviceStatus.loose);

      // Very old format: charging status
      final chargingMap = {
        'id': 'test-id-2',
        'name': 'Charging Device',
        'placement': 'rightWrist',
        'serialNumber': null,
        'status': 'charging',
      };
      final chargingDevice = Device.fromMap(chargingMap);
      expect(chargingDevice.status, DeviceStatus.charging);

      // Very old format: worn status (uses placement)
      final wornMap = {
        'id': 'test-id-3',
        'name': 'Worn Device',
        'placement': 'leftAnkle',
        'serialNumber': 'SN456',
        'status': 'worn',
      };
      final wornDevice = Device.fromMap(wornMap);
      expect(wornDevice.status, DeviceStatus.worn);
      expect(wornDevice.location, DeviceLocation.leftAnkle);
    });

    test('fromMap defaults isPoweredOn to true when not present', () {
      final map = {
        'id': 'test-id',
        'name': 'Old Device',
        'deviceType': 'watch',
        'status': 'loose',
        'location': 'leftWrist',
        'serialNumber': null,
        // No isPoweredOn field
      };
      final device = Device.fromMap(map);
      expect(device.isPoweredOn, true);
    });

    test('isWorn returns correct value based on status', () {
      expect(Device(name: 'D1', status: DeviceStatus.loose).isWorn, false);
      expect(Device(name: 'D2', status: DeviceStatus.charging).isWorn, false);
      expect(Device(name: 'D3', status: DeviceStatus.worn).isWorn, true);
    });

    test('status labels are readable', () {
      expect(Device.statusLabel(DeviceStatus.worn), 'Worn');
      expect(Device.statusLabel(DeviceStatus.loose), 'Loose');
      expect(Device.statusLabel(DeviceStatus.charging), 'Charging');
    });

    test('status short labels are single letters', () {
      expect(Device.statusShortLabel(DeviceStatus.worn), 'W');
      expect(Device.statusShortLabel(DeviceStatus.loose), 'L');
      expect(Device.statusShortLabel(DeviceStatus.charging), 'C');
    });

    test('location labels are readable', () {
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

    test('defaultLocationFor returns sensible defaults', () {
      expect(Device.defaultLocationFor(DeviceType.watch), DeviceLocation.leftWrist);
      expect(Device.defaultLocationFor(DeviceType.wristband), DeviceLocation.leftWrist);
      expect(Device.defaultLocationFor(DeviceType.ring), DeviceLocation.leftRingFinger);
      expect(Device.defaultLocationFor(DeviceType.armband), DeviceLocation.leftUpperArm);
      expect(Device.defaultLocationFor(DeviceType.chestStrap), DeviceLocation.chest);
      expect(Device.defaultLocationFor(DeviceType.headband), DeviceLocation.head);
      expect(Device.defaultLocationFor(DeviceType.other), DeviceLocation.other);
    });

    test('availableLocationsFor watch includes wrist locations only', () {
      final locations = Device.availableLocationsFor(DeviceType.watch);
      expect(locations, contains(DeviceLocation.leftWrist));
      expect(locations, contains(DeviceLocation.rightWrist));
      expect(locations.length, 2);
    });

    test('availableLocationsFor wristband includes wrist locations only', () {
      final locations = Device.availableLocationsFor(DeviceType.wristband);
      expect(locations, contains(DeviceLocation.leftWrist));
      expect(locations, contains(DeviceLocation.rightWrist));
      expect(locations.length, 2);
    });

    test('availableLocationsFor ring includes finger locations only', () {
      final locations = Device.availableLocationsFor(DeviceType.ring);
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
      expect(locations.length, 10);
    });

    test('availableLocationsFor armband includes upper arm locations only', () {
      final locations = Device.availableLocationsFor(DeviceType.armband);
      expect(locations, contains(DeviceLocation.leftUpperArm));
      expect(locations, contains(DeviceLocation.rightUpperArm));
      expect(locations.length, 2);
    });

    test('availableLocationsFor chestStrap includes chest location only', () {
      final locations = Device.availableLocationsFor(DeviceType.chestStrap);
      expect(locations, contains(DeviceLocation.chest));
      expect(locations.length, 1);
    });

    test('availableLocationsFor headband includes head location only', () {
      final locations = Device.availableLocationsFor(DeviceType.headband);
      expect(locations, contains(DeviceLocation.head));
      expect(locations.length, 1);
    });

    test('availableLocationsFor other includes all locations', () {
      final locations = Device.availableLocationsFor(DeviceType.other);
      expect(locations, equals(DeviceLocation.values));
    });
  });
}
