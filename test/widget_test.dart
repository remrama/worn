import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:worn/main.dart';

void main() {
  // Note: LogsScreen has a Timer.periodic for live duration updates,
  // so we use pump() instead of pumpAndSettle() which would wait forever.

  setUp(() {
    // Initialize SharedPreferences mock with empty data
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App renders with navigation bar', (tester) async {
    await tester.pumpWidget(const WornApp());
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    // Check for navigation destinations (Logs appears twice - in nav and as section header)
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('Logs tab shows add buttons after loading', (tester) async {
    await tester.pumpWidget(const WornApp());
    // Pump several frames to let the async _load() complete
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // Should have FABs for device, event, and note
    expect(find.byType(FloatingActionButton), findsNWidgets(3));
  });
}
