import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanjiapp/widgets/kanjiki_logo.dart';

void main() {
  testWidgets('KanjiKiLogo renders cleanly and handles fallback', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: KanjiKiLogo(size: 64),
          ),
        ),
      ),
    );

    // Verify widget mounts in tree
    expect(find.byType(KanjiKiLogo), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    // Tap callback test
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: KanjiKiLogo(
              size: 48,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(KanjiKiLogo));
    expect(tapped, isTrue);
  });
}
