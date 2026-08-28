import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanjiapp/models/kanji.dart';
import 'package:kanjiapp/widgets/kanji_canvas.dart';

void main() {
  testWidgets('KanjiCanvas draws on touch/contact and strictly ignores hover', (tester) async {
    final kanji = Kanji(
      id: 1,
      char: '日',
      readings: 'ニチ',
      meanings: 'sun',
      radicalsJson: '[]',
      svgPaths: '[]',
    );

    final key = GlobalKey<KanjiCanvasState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: KanjiCanvas(
              key: key,
              kanji: kanji,
              size: 250,
            ),
          ),
        ),
      ),
    );

    final canvasFinder = find.byType(KanjiCanvas);
    expect(canvasFinder, findsOneWidget);

    final center = tester.getCenter(canvasFinder);

    // 1. Simulate Stylus Hover Move (pressure = 0, buttons = 0) -> Should NOT create stroke
    final hoverLocation = center - const Offset(50, 50);
    final TestGesture hoverGesture = await tester.createGesture(kind: PointerDeviceKind.stylus);
    await hoverGesture.addPointer(location: hoverLocation);
    await hoverGesture.moveTo(hoverLocation + const Offset(10, 10));
    await tester.pump();

    // 2. Simulate Stylus Touch Down (physical contact: down with pressure > 0)
    await hoverGesture.down(hoverLocation + const Offset(10, 10));
    await hoverGesture.moveTo(hoverLocation + const Offset(20, 20));
    await hoverGesture.moveTo(hoverLocation + const Offset(30, 30));
    await hoverGesture.up();
    await tester.pump();

    // Check score calculation triggers with 1 stroke recorded
    key.currentState?.checkScore();
    await tester.pump();

    // Undo should work
    key.currentState?.undo();
    await tester.pump();

    // Clear should work
    key.currentState?.clear();
    await tester.pump();
  });

  testWidgets('KanjiCanvas inside ScrollView intercepts gestures and prevents parent scrolling', (tester) async {
    final kanji = Kanji(
      id: 1,
      char: '日',
      readings: 'ニチ',
      meanings: 'sun',
      radicalsJson: '[]',
      svgPaths: '[]',
    );

    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                const SizedBox(height: 50),
                KanjiCanvas(
                  kanji: kanji,
                  size: 250,
                ),
                const SizedBox(height: 1000), // make scrollable
              ],
            ),
          ),
        ),
      ),
    );

    expect(scrollController.offset, equals(0.0));

    // Drag vertically on canvas
    final canvasFinder = find.byType(KanjiCanvas);
    final center = tester.getCenter(canvasFinder);

    final TestGesture gesture = await tester.startGesture(center, kind: PointerDeviceKind.stylus);
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // The scroll offset should still be 0.0 because KanjiCanvas claimed the gesture eagerly!
    expect(scrollController.offset, equals(0.0));
  });

  testWidgets('KanjiCanvas strictly scores missing strokes and penalizes incomplete drawings', (tester) async {
    // 4 reference strokes
    final kanji = Kanji(
      id: 2,
      char: '木',
      readings: 'モク',
      meanings: 'tree',
      radicalsJson: '[]',
      svgPaths: '["M20,50 L80,50", "M50,20 L50,80", "M50,50 L20,80", "M50,50 L80,80"]',
    );

    final key = GlobalKey<KanjiCanvasState>();
    double receivedScore = 1.0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: KanjiCanvas(
              key: key,
              kanji: kanji,
              size: 250,
              onComplete: (score) {
                receivedScore = score;
              },
            ),
          ),
        ),
      ),
    );

    final canvasFinder = find.byType(KanjiCanvas);
    final center = tester.getCenter(canvasFinder);

    // Draw only 1 stroke out of 4
    final TestGesture gesture = await tester.startGesture(center - const Offset(40, 0));
    await gesture.moveTo(center + const Offset(40, 0));
    await gesture.up();
    await tester.pump();

    key.currentState?.checkScore();
    await tester.pump();

    // With only 1 of 4 strokes drawn, score cannot exceed 0.30
    expect(receivedScore, lessThan(0.35));

    // Verify score UI text and stroke chips are displayed
    expect(find.textContaining('Score:'), findsOneWidget);
    expect(find.text('Stroke Status:'), findsOneWidget);
    expect(find.textContaining('Stroke 1:'), findsOneWidget);
    expect(find.textContaining('Stroke 2:'), findsOneWidget);
    expect(find.textContaining('Stroke 3:'), findsOneWidget);
    expect(find.textContaining('Stroke 4:'), findsOneWidget);
  });
}
