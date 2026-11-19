import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worn/models/device.dart';
import 'package:worn/screens/logs_screen.dart';

/// Opens a DeviceDialog and reports what it returns through [onResult].
Future<void> openDialog(
  WidgetTester tester, {
  Device? device,
  void Function(DeviceDialogResult?)? onResult,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          final result = await showDialog<DeviceDialogResult>(
            context: context,
            builder: (_) => DeviceDialog(device: device),
          );
          onResult?.call(result);
        },
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('labels the name as nickname and has make and model fields',
      (tester) async {
    await openDialog(tester);

    expect(find.text('Nickname'), findsOneWidget);
    expect(find.text('Make (optional)'), findsOneWidget);
    expect(find.text('Model (optional)'), findsOneWidget);
    expect(find.text('Serial Number (optional)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepts a make that is not in the presets', (tester) async {
    DeviceDialogResult? result;
    await openDialog(tester, onResult: (r) => result = r);

    await tester.enterText(
        find.widgetWithText(TextField, 'Nickname'), 'Left watch');
    await tester.enterText(
        find.widgetWithText(TextField, 'Make (optional)'), 'Acme Labs');
    await tester.enterText(
        find.widgetWithText(TextField, 'Model (optional)'), 'X1');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(result?.device?.name, 'Left watch');
    expect(result?.device?.make, 'Acme Labs');
    expect(result?.device?.model, 'X1');
  });

  testWidgets('leaves blank make and model unset', (tester) async {
    DeviceDialogResult? result;
    await openDialog(tester, onResult: (r) => result = r);

    await tester.enterText(find.widgetWithText(TextField, 'Nickname'), 'Ring');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(result?.device?.make, isNull);
    expect(result?.device?.model, isNull);
  });

  testWidgets('edit dialog prefills make and model', (tester) async {
    await openDialog(tester,
        device: Device(name: 'Ring', make: 'Oura', model: 'Gen 3'));

    expect(find.widgetWithText(TextField, 'Oura'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Gen 3'), findsOneWidget);
  });
}
