import 'package:flutter_test/flutter_test.dart';
import 'package:signature/signature.dart';
import 'package:flutter/material.dart';

void main() {
  test('Controller signature', () {
    final c = SignatureController();
    c.addPoint(Point(Offset(0,0), PointType.tap, 1));
    c.addPoint(Point(Offset(1,1), PointType.move, 1));
    print(c.points);
  });
}