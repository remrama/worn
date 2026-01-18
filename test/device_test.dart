import 'package:flutter_test/flutter_test.dart';
import 'package:worn/models/device.dart';

void main() {
  group('Device model', () {
    test('creates with required fields', () {
      final device = Device(
        name: 'Test Device',
        placement: Placement.leftWrist,
      );

      expect(device.name, 'Test Device');
      expect(device.placement, Placement.leftWrist);
      expect(device.status, DeviceStatus.loose);
      expect(device.serialNumber, isNull);
      expect(device.id, isNotEmpty);
    });

    test('creates with all fields', () {
      final device = Device(
        name: 'Full Device',
        placement: Placement.rightWrist,
        serialNumber: 'SN123',
        status: DeviceStatus.worn,
      );

      expect(device.name, 'Full Device');
      expect(device.placement, Placement.rightWrist);
      expect(device.serialNumber, 'SN123');
      expect(device.status, DeviceStatus.worn);
    });

    test('copyWith preserves unchanged fields', () {
      final device = Device(
        name: 'Original',
        placement: Placement.leftWrist,
        serialNumber: 'SN123',
        status: DeviceStatus.loose,
      );

      final updated = device.copyWith(status: DeviceStatus.worn);

      expect(updated.id, device.id);
      expect(updated.name, 'Original');
      expect(updated.placement, Placement.leftWrist);
      expect(updated.serialNumber, 'SN123');
      expect(updated.status, DeviceStatus.worn);
    });

    test('toMap and fromMap roundtrip', () {
      final device = Device(
        name: 'Roundtrip',
        placement: Placement.finger,
        serialNumber: 'ABC',
        status: DeviceStatus.charging,
      );

      final map = device.toMap();
      final restored = Device.fromMap(map);

      expect(restored.id, device.id);
      expect(restored.name, device.name);
      expect(restored.placement, device.placement);
      expect(restored.serialNumber, device.serialNumber);
      expect(restored.status, device.status);
    });

    test('placement labels are readable', () {
      expect(Device.placementLabel(Placement.leftWrist), 'Left Wrist');
      expect(Device.placementLabel(Placement.rightAnkle), 'Right Ankle');
      expect(Device.placementLabel(Placement.finger), 'Finger');
    });

    test('status labels are readable', () {
      expect(Device.statusLabel(DeviceStatus.worn), 'Worn');
      expect(Device.statusLabel(DeviceStatus.loose), 'Loose');
      expect(Device.statusLabel(DeviceStatus.charging), 'Charging');
    });
  });
}
