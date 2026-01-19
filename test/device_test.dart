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
  });
}
