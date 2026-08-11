import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:no_smoke/widgets/success_check_overlay.dart';

void main() {
  testWidgets('shows a checkmark and removes itself after the animation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  SuccessCheckOverlay.show(context);
                },
                child: const Text('trigger'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
