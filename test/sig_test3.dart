import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

void main() {
  testWidgets('Draws and prints 3', (tester) async {
    final controller = SignatureController(penStrokeWidth: 5, penColor: Colors.black);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Signature(controller: controller))));
    
    await tester.drag(find.byType(Signature), const Offset(0, 100));
    for (var p in controller.points) {
      print(' ');
    }
  });
}