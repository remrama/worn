import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worn/models/device.dart';
import 'package:worn/widgets/device_type_icon.dart';

void main() {
  Future<void> pumpIcon(WidgetTester tester, Widget icon) {
    return tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: icon))),
    );
  }

  group('DeviceTypeIcon', () {
    for (final type in DeviceType.values) {
      testWidgets('${type.name} occupies a 24px square by default',
          (tester) async {
        await pumpIcon(tester, DeviceTypeIcon(type));
        expect(tester.getSize(find.byType(DeviceTypeIcon)), const Size(24, 24));
      });
    }

    testWidgets('Material icons render at full size', (tester) async {
      await pumpIcon(tester, const DeviceTypeIcon(DeviceType.watch, size: 20));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.watch);
      expect(icon.size, 20);
    });

    testWidgets('Font Awesome icons are scaled down inside the box',
        (tester) async {
      await pumpIcon(tester, const DeviceTypeIcon(DeviceType.ring, size: 24));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Device.iconFor(DeviceType.ring));
      expect(icon.size, 24 * DeviceTypeIcon.fontAwesomeScale);
      expect(tester.getSize(find.byType(DeviceTypeIcon)), const Size(24, 24));
    });

    testWidgets('size defaults to the ambient IconTheme', (tester) async {
      await pumpIcon(
        tester,
        const IconTheme(
          data: IconThemeData(size: 32),
          child: DeviceTypeIcon(DeviceType.headband),
        ),
      );
      expect(tester.getSize(find.byType(DeviceTypeIcon)), const Size(32, 32));
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.size, 32 * DeviceTypeIcon.fontAwesomeScale);
    });
  });
}
