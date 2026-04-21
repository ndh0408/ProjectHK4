import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/config/theme.dart';
import 'package:mobile/shared/widgets/app_button.dart';

void main() {
  testWidgets('AppButton renders label', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: Center(
            child: AppButton(
              label: 'Continue',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
  });
}
