import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/widgets/status_badge.dart';

void main() {
  group('StatusBadge', () {
    testWidgets('displays text with correct color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(text: 'Approved', color: Colors.green),
          ),
        ),
      );

      expect(find.text('Approved'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('Approved'));
      expect(textWidget.style?.color, Colors.green);
    });

    testWidgets('renders within a decorated container', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatusBadge(text: 'Pending', color: Colors.orange),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.ancestor(of: find.text('Pending'), matching: find.byType(Container)),
      );
      expect(container.decoration, isNotNull);
    });

    testWidgets('renders different statuses', (tester) async {
      for (final entry in {
        'AutoApproved': Colors.green,
        'FraudQueue': Colors.red,
        'Processing': Colors.blue,
      }.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatusBadge(text: entry.key, color: entry.value),
            ),
          ),
        );

        expect(find.text(entry.key), findsOneWidget);
      }
    });
  });
}
