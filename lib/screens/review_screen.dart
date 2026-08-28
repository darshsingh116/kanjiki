import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import '../models/kanji.dart';
import '../services/db_service.dart';
import '../widgets/kanji_canvas.dart';
import '../theme/app_theme.dart';

class _ReviewHistoryItem {
  final Kanji kanji;
  final int previousReps;
  final double previousEase;
  final double previousInterval;
  final DateTime? previousDueDate;
  final String? reviewLogId;
  final List<Kanji> queueSnapshot;

  _ReviewHistoryItem({
    required this.kanji,
    required this.previousReps,
    required this.previousEase,
    required this.previousInterval,
    required this.previousDueDate,
    required this.reviewLogId,
    required this.queueSnapshot,
  });
}

class ReviewScreen extends StatefulWidget {
  final String? deckId;
  final String? filter;
  final Kanji? practiceKanji;
  final String? frontMode;

  const ReviewScreen({
    super.key,
    this.deckId,
    this.filter,
    this.practiceKanji,
    this.frontMode,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final GlobalKey<KanjiCanvasState> _canvasKey = GlobalKey<KanjiCanvasState>();

  bool _isLoading = true;
  List<Kanji> _queue = [];
  final List<_ReviewHistoryItem> _history = [];
  bool _showAnswer = false;
  late String _frontMode;
  bool _isLearnMode = false;
  int _reviewAttempt = 0;

  Timer? _syncDebounceTimer;

  @override
  void initState() {
    super.initState();
    _frontMode = widget.frontMode ?? 'both';
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    if (widget.deckId != null) {
      final decks = await DbService.getDecks();
      final deck = decks.firstWhere((d) => d['id'] == widget.deckId,
          orElse: () => <String, dynamic>{});
      if (deck.isNotEmpty && deck['front_mode'] != null) {
        _frontMode = deck['front_mode'];
      }

      final cards = await DbService.getReviewQueue(deckId: widget.deckId);
      setState(() {
        _queue = cards;
        _isLoading = false;
      });
    } else if (widget.practiceKanji != null) {
      setState(() {
        _queue = [widget.practiceKanji!];
        _isLoading = false;
      });
    } else {
      final cards = await DbService.getReviewQueue();
      setState(() {
        _queue = cards;
        _isLoading = false;
      });
    }
  }

  void _answerCard(int quality) async {
    if (_queue.isEmpty) return;

    final Kanji current = _queue.first;
    final now = DateTime.now();

    final int prevReps = current.reps;
    final double prevEase = current.easeFactor;
    final double prevInterval = current.intervalDays;
    final DateTime? prevDueDate = current.dueDate;
    final List<Kanji> prevQueueSnapshot = List<Kanji>.from(_queue);
    final bool wasNew = current.reps == 0 && current.dueDate == null;

    if (quality == 0) {
      // Again (fail)
      current.reps = 0;
      current.intervalDays = 0;
      current.easeFactor = max(1.3, current.easeFactor - 0.20);
      current.dueDate = DateTime.now();
    } else {
      if (current.reps == 0) {
        current.intervalDays = quality == 5 ? 4.0 : 1.0;
      } else if (current.reps == 1) {
        current.intervalDays = quality == 5 ? 8.0 : 6.0;
      } else {
        double factor = current.easeFactor;
        if (quality == 3) {
          factor = max(1.3, current.easeFactor - 0.15);
          current.intervalDays = max(1.0, current.intervalDays * 1.2);
        } else if (quality == 5) {
          factor = current.easeFactor + 0.15;
          current.intervalDays = (current.intervalDays * factor * 1.3).roundToDouble();
        } else {
          current.intervalDays = (current.intervalDays * factor).roundToDouble();
        }
        current.easeFactor = factor;
      }
      current.reps += 1;

      final targetDate = DateTime(now.year, now.month, now.day + current.intervalDays.round());
      current.dueDate = targetDate;
    }

    await DbService.updateSRS(current);

    String? logId;
    if (current.deckId != null) {
      logId = await DbService.logReview(current.id, current.deckId, wasNew);
    }

    _history.add(_ReviewHistoryItem(
      kanji: current,
      previousReps: prevReps,
      previousEase: prevEase,
      previousInterval: prevInterval,
      previousDueDate: prevDueDate,
      reviewLogId: logId,
      queueSnapshot: prevQueueSnapshot,
    ));

    _canvasKey.currentState?.clear();

    setState(() {
      _showAnswer = false;
      _reviewAttempt++;
      if (quality > 0) {
        _queue.removeAt(0);
      } else {
        _queue.removeAt(0);
        _queue.add(current);
      }
    });
  }

  void _undoLastReview() async {
    if (_history.isEmpty) return;

    final last = _history.removeLast();
    final card = last.kanji;

    card.reps = last.previousReps;
    card.easeFactor = last.previousEase;
    card.intervalDays = last.previousInterval;
    card.dueDate = last.previousDueDate;

    await DbService.updateSRS(card);

    if (last.reviewLogId != null) {
      await DbService.deleteReviewLog(last.reviewLogId!);
    }

    _canvasKey.currentState?.clear();

    setState(() {
      _queue = List<Kanji>.from(last.queueSnapshot);
      _showAnswer = false;
      _reviewAttempt++;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text('Undid review for ${card.char}', style: const TextStyle(color: Colors.white)),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildFront(Kanji kanji) {
    if (_frontMode == 'kanji') {
      return Text(kanji.char, style: const TextStyle(fontSize: 68, fontWeight: FontWeight.bold, color: Colors.white));
    } else {
      return Text(kanji.meanings, style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.w600), textAlign: TextAlign.center);
    }
  }

  Widget _buildBackTop(Kanji kanji) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(kanji.meanings, style: const TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(kanji.readings, style: const TextStyle(fontSize: 16, color: AppColors.amber, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(kanji.char, style: const TextStyle(fontSize: 58, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        _buildRadicals(kanji),
      ],
    );
  }

  Widget _buildRadicals(Kanji kanji) {
    List<dynamic> radicals = [];
    try {
      if (kanji.radicalsJson.isNotEmpty) {
        radicals = jsonDecode(kanji.radicalsJson);
      }
    } catch (_) {}

    if (radicals.isEmpty) {
      radicals = [
        {'part': kanji.char, 'meaning': kanji.meanings}
      ];
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppStyles.neoCardDecoration(
        bg: AppColors.surfaceElevated,
        borderColor: AppColors.purple.withValues(alpha: 0.5),
        radius: 12,
        withShadow: false,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.pink, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text(
                'Components & Mnemonics',
                style: TextStyle(
                  color: AppColors.pink,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: radicals.map((r) {
              final part = r['part']?.toString() ?? '';
              final meaning = r['meaning']?.toString() ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(part, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    if (part.isNotEmpty && meaning.isNotEmpty) const SizedBox(width: 6),
                    Flexible(
                      child: Text(meaning, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_queue.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          actions: [
            if (_history.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.undo, color: Colors.white70),
                tooltip: 'Undo Last Card (Ctrl+Z)',
                onPressed: _undoLastReview,
              ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: AppStyles.neoCardDecoration(
                bg: AppColors.surface,
                borderColor: AppColors.border,
                radius: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.green, width: 2),
                    ),
                    child: const Icon(Icons.check_circle_outline, color: AppColors.green, size: 36),
                  ),
                  const SizedBox(height: 20),
                  const Text('All Reviews Finished!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Great job! You have cleared all due and new cards for this session.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_history.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.cyan,
                              side: const BorderSide(color: AppColors.cyan, width: 1.5),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            icon: const Icon(Icons.undo, size: 16),
                            onPressed: _undoLastReview,
                            label: const Text('Undo Last Card'),
                          ),
                        ),
                      ElevatedButton(
                        style: AppStyles.neoButtonStyle(
                          bg: AppColors.primary,
                          borderColor: AppColors.primaryLight,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Return Home', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      );
    }

    final currentCard = _queue.first;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undoLastReview,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _undoLastReview,
        const SingleActivator(LogicalKeyboardKey.keyZ): _undoLastReview,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.bgDark,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Text(
                '${_queue.length} remaining',
                style: const TextStyle(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            actions: [
              if (_history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.white),
                  tooltip: 'Undo Card (Ctrl+Z)',
                  onPressed: _undoLastReview,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isLearnMode ? AppColors.pink : AppColors.primaryLight,
                    side: BorderSide(color: _isLearnMode ? AppColors.pink : AppColors.borderLight, width: 1.5),
                    backgroundColor: AppColors.surfaceElevated,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => setState(() => _isLearnMode = !_isLearnMode),
                  icon: Icon(_isLearnMode ? Icons.close : Icons.school, size: 16),
                  label: Text(_isLearnMode ? 'Exit Guide' : 'Learn Mode', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
          body: SafeArea(
            child: _isLearnMode
                ? _buildLearnMode(currentCard)
                : _buildReviewMode(currentCard),
          ),
        ),
      ),
    );
  }

  Widget _buildLearnMode(Kanji kanji) {
    final strokeCount = _getSvgStrokeCount(kanji.svgPaths);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final canvasSize = (screenHeight * 0.35).clamp(200.0, 300.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: AppStyles.neoCardDecoration(
                  bg: AppColors.surface,
                  borderColor: AppColors.border,
                  radius: 18,
                ),
                child: Column(
                  children: [
                    Text(kanji.char, style: const TextStyle(fontSize: 68, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 14),
                    _buildRadicals(kanji),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppStyles.neoCardDecoration(
                        bg: AppColors.surfaceElevated,
                        borderColor: AppColors.cyan.withValues(alpha: 0.5),
                        radius: 14,
                        withShadow: false,
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.touch_app, size: 16, color: AppColors.cyan),
                              const SizedBox(width: 6),
                              Text(
                                'Stroke Guide ($strokeCount strokes)',
                                style: const TextStyle(color: AppColors.cyan, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          KanjiCanvas(
                            key: ValueKey('learn_${kanji.id}'),
                            kanji: kanji,
                            showGuide: true,
                            showCheckButton: false,
                            size: canvasSize,
                            onComplete: null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: AppStyles.neoCardDecoration(
                        bg: AppColors.surfaceElevated,
                        borderColor: AppColors.border,
                        radius: 12,
                        withShadow: false,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Readings: ${kanji.readings}', style: const TextStyle(color: AppColors.amber, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('Meanings: ${kanji.meanings}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewMode(Kanji kanji) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final canvasSize = (screenHeight * 0.35).clamp(200.0, 300.0);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      decoration: AppStyles.neoCardDecoration(
                        bg: AppColors.surface,
                        borderColor: AppColors.border,
                        radius: 18,
                      ),
                      child: Column(
                        children: [
                          if (!_showAnswer) _buildFront(kanji) else _buildBackTop(kanji),
                          const SizedBox(height: 16),
                          KanjiCanvas(
                            key: _canvasKey,
                            kanji: kanji,
                            resetKey: _reviewAttempt,
                            showGuide: _showAnswer,
                            showCheckButton: true,
                            size: canvasSize,
                            onComplete: (score) {
                              if (!_showAnswer && score >= 0.85) {
                                setState(() => _showAnswer = true);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Sticky Bottom SRS Buttons
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
          ),
          padding: const EdgeInsets.all(12.0),
          child: SafeArea(
            top: false,
            child: !_showAnswer
                ? Row(
                    children: [
                      if (_history.isNotEmpty) ...[
                        IconButton.filledTonal(
                          icon: const Icon(Icons.undo, color: Colors.white),
                          tooltip: 'Undo Last Card (Ctrl+Z)',
                          onPressed: _undoLastReview,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceElevated,
                            side: const BorderSide(color: AppColors.border, width: 1.5),
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            style: AppStyles.neoButtonStyle(
                              bg: AppColors.primary,
                              borderColor: AppColors.primaryLight,
                              radius: 12,
                            ),
                            onPressed: () {
                              setState(() => _showAnswer = true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _canvasKey.currentState?.checkScore();
                              });
                            },
                            child: const Text('Show Answer', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _AnswerButton(label: 'Again', color: AppColors.srsLearn, onPressed: () => _answerCard(0)),
                          _AnswerButton(label: 'Hard', color: AppColors.amber, onPressed: () => _answerCard(3)),
                          _AnswerButton(label: 'Good', color: AppColors.srsReview, onPressed: () => _answerCard(4)),
                          _AnswerButton(label: 'Easy', color: AppColors.srsEasy, onPressed: () => _answerCard(5)),
                        ],
                      ),
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _undoLastReview,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.undo, size: 14, color: AppColors.textMuted),
                                SizedBox(width: 4),
                                Text('Undo Previous Card (Ctrl+Z)', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  int _getSvgStrokeCount(String svgPaths) {
    try {
      final decoded = jsonDecode(svgPaths);
      if (decoded is List) {
        return decoded.length;
      }
    } catch (_) {}
    return 0;
  }

  @override
  void dispose() {
    _syncDebounceTimer?.cancel();
    super.dispose();
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _AnswerButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.18),
            foregroundColor: color,
            side: BorderSide(color: color, width: 1.5),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onPressed,
          child: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
