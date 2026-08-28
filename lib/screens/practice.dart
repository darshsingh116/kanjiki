import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/kanji.dart';
import '../widgets/kanji_canvas.dart';

class PracticeScreen extends StatefulWidget {
  final Kanji kanji;

  const PracticeScreen({super.key, required this.kanji});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  bool _isLearnMode = false;
  bool _showAnswer = false;
  final GlobalKey<KanjiCanvasState> _canvasKey = GlobalKey<KanjiCanvasState>();

  int _getSvgStrokeCount(String svgPaths) {
    try {
      final decoded = jsonDecode(svgPaths);
      if (decoded is List) {
        return decoded.length;
      }
    } catch (_) {}
    return 0;
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
    final kanji = widget.kanji;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          kanji.char,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E1E2C),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => setState(() => _isLearnMode = !_isLearnMode),
              icon: Icon(_isLearnMode ? Icons.edit : Icons.school),
              label: Text(_isLearnMode ? 'Practice Mode' : 'Learn Mode'),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: _isLearnMode ? _buildLearnMode(kanji) : _buildPracticeMode(kanji),
      ),
    );
  }

  Widget _buildLearnMode(Kanji kanji) {
    final strokeCount = _getSvgStrokeCount(kanji.svgPaths);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final canvasSize = (screenHeight * 0.35).clamp(200.0, 300.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                kanji.char,
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.white),
              ),
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
                    const Text(
                      'Stroke Order Guide',
                      style: TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Number of strokes: $strokeCount',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
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
                    const Text(
                      'Information:',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Readings: ${kanji.readings}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('Meaning: ${kanji.meanings}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    if (kanji.jlpt != null) ...[
                      const SizedBox(height: 8),
                      Text('JLPT: N${kanji.jlpt == 4 ? "5" : kanji.jlpt == 3 ? "4" : kanji.jlpt == 2 ? "3/2" : "1"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPracticeMode(Kanji kanji) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final canvasSize = (screenHeight * 0.35).clamp(200.0, 300.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Text(
                kanji.meanings,
                style: const TextStyle(fontSize: 20, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                kanji.readings,
                style: const TextStyle(fontSize: 16, color: Colors.yellowAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_showAnswer) ...[
                Text(
                  kanji.char,
                  style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              KanjiCanvas(
                key: _canvasKey,
                kanji: kanji,
                showGuide: _showAnswer,
                showCheckButton: true,
                size: canvasSize,
                onComplete: (score) {
                  if (!_showAnswer && score >= 0.85) {
                    setState(() => _showAnswer = true);
                  }
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _showAnswer = !_showAnswer);
                },
                icon: Icon(_showAnswer ? Icons.visibility_off : Icons.visibility),
                label: Text(_showAnswer ? 'Hide Guide' : 'Show Guide'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: const BorderSide(color: Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 16),
              _buildRadicals(kanji),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
