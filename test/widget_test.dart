// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mechtech/main.dart';
import 'package:mechtech/services/app_state.dart';

void main() {
  testWidgets('Login screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MechTechApp(),
      ),
    );

    // Verify that login elements exist
    expect(find.text('MechTech'), findsOneWidget);
    expect(find.text('Premium Mechanic Service App'), findsOneWidget);
    expect(find.text('Enter App'), findsOneWidget);
  });
}
