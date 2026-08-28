import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:async';
import '../models/kanji.dart';
import '../services/db_service.dart';
import '../widgets/kanji_canvas.dart';

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
    _frontMode = widget.frontMode ?? 'both'; // Default fallback
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    if (widget.deckId != null) {
      // Look up deck settings to get frontMode first (if possible)
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
      // General review (all decks)
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

    // Snapshot state for Undo
    final int prevReps = current.reps;
    final double prevEase = current.easeFactor;
    final double prevInterval = current.intervalDays;
    final DateTime? prevDueDate = current.dueDate;
    final List<Kanji> prevQueueSnapshot = List<Kanji>.from(_queue);
    final bool wasNew = current.reps == 0 && current.dueDate == null;

    // SM-2 day-based logic
    if (quality == 0) {
      // Again (fail)
      current.reps = 0;
      current.intervalDays = 0;
      current.easeFactor = max(1.3, current.easeFactor - 0.20);
      current.dueDate = DateTime.now(); // Due immediately in learning queue
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

      // Day-based due date (starts at 00:00:00 on target calendar day)
      final targetDate = DateTime(now.year, now.month, now.day + current.intervalDays.round());
      current.dueDate = targetDate;
    }

    await DbService.updateSRS(current);
    
    // Always log review for limits tracking and Undo history
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
        _queue.removeAt(0); // Card graduated / done for now
      } else {
        // Move "Again" card to back of queue
        _queue.removeAt(0);
        _queue.add(current);
      }
    });
  }

  void _undoLastReview() async {
    if (_history.isEmpty) return;

    final last = _history.removeLast();
    final card = last.kanji;

    // Restore prior card SRS properties
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
          content: Text('Undid review for ${card.char}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildFront(Kanji kanji) {
    if (_frontMode == 'kanji') {
      return Text(kanji.char, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white));
    } else {
      return Text(kanji.meanings, style: const TextStyle(fontSize: 28, color: Colors.white), textAlign: TextAlign.center);
    }
  }

  Widget _buildBackTop(Kanji kanji) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(kanji.meanings, style: const TextStyle(fontSize: 18, color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(kanji.readings, style: const TextStyle(fontSize: 16, color: Colors.yellowAccent), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(kanji.char, style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: Colors.white)),
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

    // Fallback: If kanji itself is a primary radical or has no sub-radicals, show itself
    if (radicals.isEmpty) {
      radicals = [
        {'part': kanji.char, 'meaning': kanji.meanings}
      ];
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Components & Mnemonics',
            style: TextStyle(
              color: Colors.purpleAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
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
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(part, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    if (part.isNotEmpty && meaning.isNotEmpty)
                      const SizedBox(width: 6),
                    Flexible(
                      child: Text(meaning, style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_queue.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E2C),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 80),
              const SizedBox(height: 20),
              const Text('All reviews finished!',
                  style: TextStyle(color: Colors.white, fontSize: 24)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_history.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.undo),
                        onPressed: _undoLastReview,
                        label: const Text('Undo Last Card'),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              )
            ],
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
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            title: Text('${_queue.length} remaining'),
            backgroundColor: const Color(0xFF1E1E2C),
            actions: [
              if (_history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.white),
                  tooltip: 'Undo Card (Ctrl+Z)',
                  onPressed: _undoLastReview,
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () => setState(() => _isLearnMode = !_isLearnMode),
                    icon: Icon(_isLearnMode ? Icons.close : Icons.school),
                    label: Text(_isLearnMode ? 'Exit Learn' : 'Learn Mode'),
                  ),
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

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(kanji.char, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    _buildRadicals(kanji),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Column(
                        children: [
                          const Text('Stroke Order Guide', style: TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text('Number of strokes: $strokeCount', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 12),
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
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Information:', style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Readings: ${kanji.readings}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          const SizedBox(height: 8),
                          Text('Meaning: ${kanji.meanings}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewMode(Kanji kanji) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final canvasSize = (screenHeight * 0.35).clamp(200.0, 300.0); // responsive canvas

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    if (!_showAnswer)
                      _buildFront(kanji)
                    else
                      _buildBackTop(kanji),
                    const SizedBox(height: 20),
                    KanjiCanvas(
                      key: ValueKey('review_${kanji.id}_$_reviewAttempt'),
                      kanji: kanji,
                      resetKey: _reviewAttempt,
                      showGuide: _showAnswer,
                      showCheckButton: false,
                      size: canvasSize,
                      onComplete: (score) {
                        if (!_showAnswer && score >= 0.85) {
                          setState(() => _showAnswer = true);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                             _canvasKey.currentState?.checkScore();
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Sticky Bottom SRS Buttons
        Container(
          color: const Color(0xFF1E1E2C),
          padding: const EdgeInsets.all(12.0),
          child: SafeArea(
            top: false,
            child: !_showAnswer
                ? SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: () {
                        setState(() => _showAnswer = true);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _canvasKey.currentState?.checkScore();
                        });
                      },
                      child: const Text('Show Answer', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _AnswerButton(label: 'Again', color: Colors.redAccent, onPressed: () => _answerCard(0)),
                      _AnswerButton(label: 'Hard', color: Colors.orangeAccent, onPressed: () => _answerCard(3)),
                      _AnswerButton(label: 'Good', color: Colors.greenAccent, onPressed: () => _answerCard(4)),
                      _AnswerButton(label: 'Easy', color: Colors.lightBlueAccent, onPressed: () => _answerCard(5)),
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

  const _AnswerButton(
      {required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.2), // Dark mode friendly tint
            side: BorderSide(color: color, width: 2), // Outline
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onPressed,
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
