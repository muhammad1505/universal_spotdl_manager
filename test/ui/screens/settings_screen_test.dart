import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_spotdl_manager/screens/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsScreen(enableRuntimeProviders: false)),
      ),
    );

    expect(find.text('Settings'), findsAtLeastNWidgets(1));
    expect(find.text('Queue Engine'), findsOneWidget);
    expect(
      find.text('Environment check disabled for test mode'),
      findsOneWidget,
    );
  });
}
