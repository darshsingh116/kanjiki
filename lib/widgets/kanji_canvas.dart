import 'dart:convert';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../models/kanji.dart';
import '../theme/app_theme.dart';

class KanjiCanvas extends StatefulWidget {
  final Kanji kanji;
  final bool showGuide;
  final bool showCheckButton;
  final double size;
  final Function(double)? onComplete;
  final int resetKey;

  const KanjiCanvas({
    super.key,
    required this.kanji,
    this.showGuide = false,
    this.showCheckButton = true,
    this.size = 250,
    this.onComplete,
    this.resetKey = 0,
  });

  @override
  State<KanjiCanvas> createState() => KanjiCanvasState();
}

class KanjiCanvasState extends State<KanjiCanvas> {
  final List<List<Offset>> _strokes = [];
  final List<Offset> _currentStroke = [];
  bool _isDrawing = false;
  int? _activePointerId;

  double? _lastScore;
  double _bestScore = 0.0;
  List<double>? _strokeAccuracy;

  @override
  void didUpdateWidget(KanjiCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kanji.id != widget.kanji.id || oldWidget.resetKey != widget.resetKey) {
      clear();
    }
  }

  void undo() {
    setState(() {
      if (_strokes.isNotEmpty) {
        _strokes.removeLast();
      }
      _lastScore = null;
      _strokeAccuracy = null;
    });
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
      _isDrawing = false;
      _activePointerId = null;
      _lastScore = null;
      _bestScore = 0.0;
      _strokeAccuracy = null;
    });
  }

  List<Offset> _resample(List<Offset> source, int n) {
    if (source.isEmpty) return [];
    if (source.length == 1) return List.filled(n, source.first);
    List<Offset> points = List.from(source);

    double totalLength = 0;
    for (int i = 1; i < points.length; i++) {
      totalLength += (points[i] - points[i - 1]).distance;
    }
    if (totalLength == 0) return List.filled(n, points.first);

    double step = totalLength / (n - 1);
    List<Offset> resampled = [points.first];
    double distanceAccumulated = 0;

    int i = 1;
    while (i < points.length && resampled.length < n) {
      double d = (points[i] - points[i - 1]).distance;
      if (distanceAccumulated + d >= step) {
        double t = (step - distanceAccumulated) / d;
        Offset p = Offset.lerp(points[i - 1], points[i], t)!;
        resampled.add(p);
        points[i - 1] = p; // Mutable step
        distanceAccumulated = 0;
      } else {
        distanceAccumulated += d;
        i++;
      }
    }

    while (resampled.length < n) {
      resampled.add(points.last);
    }
    return resampled;
  }

  double _evaluateStrokePair(List<Offset> refStroke, List<Offset> userStroke, double canvasSize) {
    if (refStroke.isEmpty || userStroke.isEmpty) return 0.0;

    // 1. Length calculation on raw points before resampling
    double refLength = 0.0;
    for (int i = 1; i < refStroke.length; i++) {
      refLength += (refStroke[i] - refStroke[i - 1]).distance;
    }
    double userLength = 0.0;
    for (int i = 1; i < userStroke.length; i++) {
      userLength += (userStroke[i] - userStroke[i - 1]).distance;
    }

    // Length Ratio penalty: allows normal handwriting variation (0.6x to 1.6x)
    // but heavily penalizes drawing a huge L for a short tick or vice versa
    double lengthFactor = 1.0;
    if (refLength > 0 && userLength > 0) {
      final ratio = userLength / refLength;
      if (ratio < 0.60) {
        lengthFactor = (1.0 - (0.60 - ratio) * 1.5).clamp(0.0, 1.0);
      } else if (ratio > 1.60) {
        lengthFactor = (1.0 - (ratio - 1.60) * 0.9).clamp(0.0, 1.0);
      }
    }

    final ref = _resample(refStroke, 30);
    final user = _resample(userStroke, 30);

    // 2. Direction & Trajectory check (Vector alignment between start and end)
    final refVec = ref.last - ref.first;
    final userVec = user.last - user.first;
    final refLen = refVec.distance;
    final userLen = userVec.distance;

    double dirScore = 1.0;
    if (refLen > canvasSize * 0.04 && userLen > canvasSize * 0.04) {
      final dot = (refVec.dx * userVec.dx + refVec.dy * userVec.dy) / (refLen * userLen);
      if (dot >= 0.50) {
        dirScore = 1.0; // Within 60 degrees of expected angle
      } else if (dot >= 0.0) {
        dirScore = (0.40 + 0.60 * (dot / 0.50)).clamp(0.0, 1.0);
      } else {
        // Reverse direction (angle > 90 degrees)
        dirScore = 0.10;
      }
    }

    // 3. Curvature & Midpoint Shape Check (Differentiating straight lines from L/corners)
    final refChordMid = (ref.first + ref.last) / 2.0;
    final userChordMid = (user.first + user.last) / 2.0;
    final refSagitta = (ref[15] - refChordMid).distance;
    final userSagitta = (user[15] - userChordMid).distance;
    final bendDiff = (userSagitta - refSagitta).abs() / canvasSize;
    final shapeFactor = (1.0 - bendDiff * 2.5).clamp(0.20, 1.0);

    // 4. Windowed Dynamic Time Warping (DTW) distance (Window size = 10 for handwriting elasticity)
    const int n = 30;
    const int w = 10;
    final List<List<double>> dtw = List.generate(n + 1, (_) => List.filled(n + 1, double.infinity));
    dtw[0][0] = 0.0;

    for (int i = 1; i <= n; i++) {
      final int jStart = max(1, i - w);
      final int jEnd = min(n, i + w);
      for (int j = jStart; j <= jEnd; j++) {
        final cost = (ref[i - 1] - user[j - 1]).distance;
        final prevMin = min(dtw[i - 1][j], min(dtw[i][j - 1], dtw[i - 1][j - 1]));
        if (prevMin != double.infinity) {
          dtw[i][j] = cost + prevMin;
        }
      }
    }

    double avgDist = dtw[n][n];
    if (avgDist == double.infinity) {
      double fallbackSum = 0.0;
      for (int i = 0; i < n; i++) {
        fallbackSum += (ref[i] - user[i]).distance;
      }
      avgDist = fallbackSum / n;
    } else {
      avgDist = avgDist / (2.0 * n);
    }

    // 5. Normalized DTW and Endpoint alignment
    final normDist = avgDist / (canvasSize * 0.24);
    final dtwSim = (1.0 - normDist).clamp(0.0, 1.0);

    final startDist = (ref.first - user.first).distance;
    final endDist = (ref.last - user.last).distance;
    final endpointDist = (startDist + endDist) / (2.0 * canvasSize);
    final endpointSim = (1.0 - endpointDist * 1.5).clamp(0.0, 1.0);

    // Composite accuracy score
    final double rawSim = (dtwSim * 0.40 + endpointSim * 0.25 + dirScore * 0.20 + shapeFactor * 0.15) * lengthFactor;
    return rawSim.clamp(0.0, 1.0);
  }

  void checkScore() {
    List<dynamic> pathStrings = [];
    try {
      if (widget.kanji.svgPaths.isNotEmpty) {
        pathStrings = jsonDecode(widget.kanji.svgPaths);
      }
    } catch (_) {}

    if (pathStrings.isEmpty) {
      const s = 1.0;
      setState(() => _lastScore = s);
      if (s > _bestScore) _bestScore = s;
      if (widget.onComplete != null) widget.onComplete!(s);
      return;
    }

    final scale = widget.size / 109.0;

    // Parse reference strokes from SVG paths
    List<List<Offset>> svgStrokes = [];
    for (final p in pathStrings) {
      try {
        final path = parseSvgPathData(p.toString());
        final metrics = path.computeMetrics();
        List<Offset> strokePoints = [];
        for (final metric in metrics) {
          for (double i = 0; i < metric.length; i += 1.0) {
            final tangent = metric.getTangentForOffset(i);
            if (tangent != null) {
              strokePoints.add(tangent.position * scale);
            }
          }
        }
        if (strokePoints.isNotEmpty) svgStrokes.add(strokePoints);
      } catch (_) {
        continue;
      }
    }

    // Extract user strokes from canvas
    final List<List<Offset>> userStrokes = [
      for (var s in _strokes)
        if (s.isNotEmpty) List<Offset>.from(s)
    ];
    if (_currentStroke.isNotEmpty) {
      userStrokes.add(List<Offset>.from(_currentStroke));
    }

    final int expectedCount = svgStrokes.length;
    final int drawnCount = userStrokes.length;

    // No user input
    if (userStrokes.isEmpty) {
      setState(() {
        _lastScore = 0.0;
        _strokeAccuracy = List.filled(expectedCount, 0.0);
      });
      if (widget.onComplete != null) widget.onComplete!(0.0);
      return;
    }

    // No reference strokes
    if (svgStrokes.isEmpty) {
      setState(() => _lastScore = 0.5);
      if (widget.onComplete != null) widget.onComplete!(0.5);
      return;
    }

    double totalAccuracy = 0.0;
    List<double> strokeAccuracies = [];

    // Evaluate each expected stroke 1-to-1
    for (int i = 0; i < expectedCount; i++) {
      if (i < drawnCount) {
        final strokeSim = _evaluateStrokePair(svgStrokes[i], userStrokes[i], widget.size);
        strokeAccuracies.add(strokeSim);
        totalAccuracy += strokeSim;
      } else {
        // Missing stroke -> 0%
        strokeAccuracies.add(0.0);
      }
    }

    // Extra strokes drawn beyond expected count (explicitly graded 0.0 / Invalid)
    int extraCount = max(0, drawnCount - expectedCount);
    for (int i = expectedCount; i < drawnCount; i++) {
      strokeAccuracies.add(0.0);
    }

    // Extra stroke penalty (each extra stroke penalizes the final grade)
    double extraPenalty = extraCount * 0.20;
    double divisor = (expectedCount + extraCount * 0.5).toDouble();
    double finalScore = divisor > 0 ? ((totalAccuracy - extraPenalty) / divisor).clamp(0.0, 1.0) : 0.0;

    setState(() {
      _lastScore = finalScore;
      _strokeAccuracy = strokeAccuracies;
      if (finalScore > _bestScore) _bestScore = finalScore;
    });

    if (widget.onComplete != null) {
      widget.onComplete!(finalScore);
    }
  }

  // --- Tablet & Stylus-Aware Pointer Handling (Hover Rejection) ---

  void _onPointerDown(PointerDownEvent event) {
    // Check for real contact:
    // For stylus / graphics tablet: must have physical contact (pressure > 0 or buttons != 0 or down)
    // For mouse: primary mouse button must be pressed
    // For touch: touch contact is active
    if (event.kind == PointerDeviceKind.mouse) {
      if ((event.buttons & kPrimaryMouseButton) == 0) return;
    } else if (event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) {
      // If hover state (no pressure and no buttons), reject
      if (event.buttons == 0 && event.pressure == 0.0) return;
    }

    setState(() {
      _isDrawing = true;
      _activePointerId = event.pointer;
      _currentStroke.clear();
      _currentStroke.add(event.localPosition);
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_isDrawing || event.pointer != _activePointerId) return;

    // CRITICAL FOR GRAPHICS TABLETS (Gaomon, Wacom, Huion on Chrome/Web):
    // Graphic tablets emit hover movement events. If the pen is hovering in the air without contact,
    // event.buttons is 0 and event.pressure is 0.0.
    if ((event.kind == PointerDeviceKind.stylus || event.kind == PointerDeviceKind.invertedStylus) &&
        event.buttons == 0 && event.pressure == 0.0) {
      // Pen lifted off surface into hover range -> finalize stroke immediately!
      _endStroke();
      return;
    }

    if (event.kind == PointerDeviceKind.mouse && (event.buttons & kPrimaryMouseButton) == 0) {
      _endStroke();
      return;
    }

    setState(() {
      _currentStroke.add(event.localPosition);
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer == _activePointerId) {
      _endStroke();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _activePointerId) {
      _endStroke();
    }
  }

  void _endStroke() {
    if (!_isDrawing) return;
    setState(() {
      if (_currentStroke.isNotEmpty) {
        _strokes.add(List<Offset>.from(_currentStroke));
        _currentStroke.clear();
      }
      _isDrawing = false;
      _activePointerId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> pathStrings = [];
    try {
      if (widget.kanji.svgPaths.isNotEmpty) {
        pathStrings = jsonDecode(widget.kanji.svgPaths);
      }
    } catch (_) {}

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_lastScore != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: (_lastScore! >= 0.70
                      ? AppColors.green
                      : _lastScore! >= 0.45
                          ? AppColors.amber
                          : AppColors.red)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _lastScore! >= 0.70
                    ? AppColors.green
                    : _lastScore! >= 0.45
                        ? AppColors.amber
                        : AppColors.red,
                width: 1.5,
              ),
            ),
            child: Text(
              'Stroke Score: ${(_lastScore! * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _lastScore! >= 0.70
                    ? AppColors.green
                    : _lastScore! >= 0.45
                        ? AppColors.amber
                        : AppColors.red,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.borderLight, width: 2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppStyles.neoShadow(offset: 3),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(),
                  ),
                ),
                if ((widget.showGuide || _strokeAccuracy != null) && pathStrings.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _SvgPathPainter(
                        pathStrings.map((e) => e.toString()).toList(),
                        _strokeAccuracy,
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: RawGestureDetector(
                    gestures: <Type, GestureRecognizerFactory>{
                      EagerGestureRecognizer: GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                        (EagerGestureRecognizer instance) {},
                      ),
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      onPointerCancel: _onPointerCancel,
                      child: CustomPaint(
                        painter: _UserStrokePainter(
                          strokes: _strokes,
                          currentStroke: _currentStroke,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                side: const BorderSide(color: AppColors.border, width: 1.5),
                padding: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.undo, color: AppColors.textPrimary, size: 20),
              onPressed: undo,
              tooltip: 'Undo stroke',
            ),
            if (widget.showCheckButton) ...[
              const SizedBox(width: 14),
              ElevatedButton.icon(
                onPressed: checkScore,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Check Stroke', style: TextStyle(fontWeight: FontWeight.bold)),
                style: AppStyles.neoButtonStyle(
                  bg: AppColors.primary,
                  borderColor: AppColors.primaryLight,
                  radius: 10,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
            const SizedBox(width: 14),
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
                side: const BorderSide(color: AppColors.border, width: 1.5),
                padding: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh, color: AppColors.textPrimary, size: 20),
              onPressed: clear,
              tooltip: 'Clear canvas',
            ),
          ],
        ),
        if (_strokeAccuracy != null && _strokeAccuracy!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const Text(
                  'Stroke Status:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: _strokeAccuracy!
                      .asMap()
                      .entries
                      .map((entry) {
                        int index = entry.key;
                        double accuracy = entry.value;
                        bool isExtra = index >= pathStrings.length;
                        Color color = isExtra
                            ? Colors.red
                            : accuracy >= 0.70
                                ? Colors.green
                                : accuracy >= 0.45
                                    ? Colors.amber
                                    : Colors.red;
                        return Chip(
                          label: Text(
                            isExtra
                                ? 'Extra Stroke ${index + 1}: Invalid'
                                : 'Stroke ${index + 1}: ${(accuracy * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 11),
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          backgroundColor: color.withValues(alpha: 0.3),
                          side: BorderSide(color: color),
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _UserStrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  static const Color strokeColor = Colors.black;
  static const double strokeWidth = 4.5;

  _UserStrokePainter({
    required this.strokes,
    required this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    void drawPoints(List<Offset> pts) {
      if (pts.isEmpty) return;
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, strokeWidth / 2, dotPaint);
        return;
      }
      if (pts.length == 2) {
        canvas.drawLine(pts[0], pts[1], linePaint);
        return;
      }

      final path = Path();
      path.moveTo(pts[0].dx, pts[0].dy);

      for (int i = 1; i < pts.length - 1; i++) {
        final p0 = pts[i];
        final p1 = pts[i + 1];
        final midX = (p0.dx + p1.dx) / 2;
        final midY = (p0.dy + p1.dy) / 2;
        path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
      canvas.drawPath(path, linePaint);
    }

    for (final s in strokes) {
      drawPoints(s);
    }
    if (currentStroke.isNotEmpty) {
      drawPoints(currentStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _UserStrokePainter oldDelegate) => true;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SvgPathPainter extends CustomPainter {
  final List<String> paths;
  final List<double>? strokeAccuracy;
  _SvgPathPainter(this.paths, [this.strokeAccuracy]);

  Offset? _getPathStartPoint(String pathStr) {
    try {
      final movePattern = RegExp(r'M\s*([-\d.]+)[,\s]+([-\d.]+)');
      final match = movePattern.firstMatch(pathStr);
      if (match != null) {
        final x = double.parse(match.group(1)!);
        final y = double.parse(match.group(2)!);
        return Offset(x, y);
      }
    } catch (_) {}
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 109.0;

    final List<Offset> strokeStarts = [];
    for (final pathStr in paths) {
      final startPoint = _getPathStartPoint(pathStr);
      strokeStarts.add(startPoint ?? Offset.zero);
    }

    canvas.save();
    canvas.scale(scale, scale);

    for (int i = 0; i < paths.length; i++) {
      final p = paths[i];

      Color strokeColor = Colors.grey.withValues(alpha: 0.35);
      double strokeWidth = 3.5;
      if (strokeAccuracy != null) {
        if (i < strokeAccuracy!.length) {
          final acc = strokeAccuracy![i];
          if (acc >= 0.70) {
            strokeColor = Colors.green.withValues(alpha: 0.85);
            strokeWidth = 4.5;
          } else if (acc >= 0.45) {
            strokeColor = Colors.orange.withValues(alpha: 0.85);
            strokeWidth = 4.5;
          } else {
            strokeColor = Colors.red.withValues(alpha: 0.85);
            strokeWidth = 4.5;
          }
        } else {
          strokeColor = Colors.red.withValues(alpha: 0.85);
          strokeWidth = 4.5;
        }
      }

      final paint = Paint()
        ..color = strokeColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      try {
        final path = parseSvgPathData(p);
        canvas.drawPath(path, paint);
      } catch (_) {
        continue;
      }
    }

    canvas.restore();

    for (int i = 0; i < strokeStarts.length; i++) {
      try {
        final scaledPos = strokeStarts[i] * scale;
        Color numColor = Colors.blueAccent;
        if (strokeAccuracy != null && i < strokeAccuracy!.length) {
          final acc = strokeAccuracy![i];
          if (acc >= 0.70) {
            numColor = Colors.green;
          } else if (acc >= 0.45) {
            numColor = Colors.orange;
          } else {
            numColor = Colors.red;
          }
        }

        // Circular background badge behind stroke number for crisp readability
        final bgPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.95)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(scaledPos, 9.0, bgPaint);

        final borderPaint = Paint()
          ..color = numColor
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(scaledPos, 9.0, borderPaint);

        final textPainter = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: TextStyle(
              color: numColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          scaledPos - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      } catch (_) {
        continue;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SvgPathPainter oldDelegate) {
    return oldDelegate.paths != paths || oldDelegate.strokeAccuracy != strokeAccuracy;
  }
}
