// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nab3_gded/screens/onboarding_screen.dart';

void main() {
  testWidgets('Onboarding screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We need to provide a mock AuthProvider since main.dart uses it.
    // However, for a simple smoke test, we can try to pump the app as is,
    // but it will likely fail due to Firebase initialization in main().

    // Instead of pumping the whole MyApp which initializes Firebase,
    // let's pump the OnboardingScreen directly for a component test.
    await tester.pumpWidget(const MaterialApp(
      home: OnboardingScreen(),
    ));

    // Verify that the logo "نبع" is present.
    expect(find.text('نبع'), findsOneWidget);

    // Verify that the welcome text "مرحباً بك في نبع" is present.
    expect(find.text('مرحباً بك في نبع'), findsOneWidget);

    // Verify that the "إنشاء حساب جديد" button is present.
    expect(find.text('إنشاء حساب جديد'), findsOneWidget);

    // Verify that the "تسجيل الدخول" button is present.
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });
}
