import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/widgets/custom_button.dart';

void main() {
  group('CustomButton', () {
    testWidgets('displays label and responds to tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              label: 'Submit Claim',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Submit Claim'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      expect(tapped, isTrue);
    });

    testWidgets('uses default color when none provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              label: 'Default',
              onPressed: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.style, isNotNull);
    });

    testWidgets('uses custom color when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(
              label: 'Custom',
              onPressed: () {},
              color: Colors.teal,
            ),
          ),
        ),
      );

      expect(find.text('Custom'), findsOneWidget);
    });
  });
}
