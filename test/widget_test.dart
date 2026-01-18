import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worn/main.dart';

void main() {
  testWidgets('App renders with navigation bar', (tester) async {
    await tester.pumpWidget(const WornApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byIcon(Icons.watch), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('Devices tab shows add button', (tester) async {
    await tester.pumpWidget(const WornApp());

    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
