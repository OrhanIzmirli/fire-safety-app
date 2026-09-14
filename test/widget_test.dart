// Basic widget smoke test for the Fire Safety App home screen.
//
// It renders HomePage in isolation (without going through FireSafetyApp's
// Firebase/notifications initialization) and checks that the title and the
// three primary action buttons are present.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:firesafetapp/main.dart';

void main() {
  testWidgets('HomePage shows title and primary action buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));

    expect(find.text('🔥 Fire Safety App'), findsOneWidget);
    expect(find.text('Yangın Bildir'), findsOneWidget);
    expect(find.text('Yangın Verilerini Çek'), findsOneWidget);
    expect(find.text('Haritada Göster'), findsOneWidget);
  });
}
