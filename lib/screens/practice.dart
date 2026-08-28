import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/kanji.dart';
import '../widgets/kanji_canvas.dart';
import '../theme/app_theme.dart';

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
    final kanji = widget.kanji;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Kanji: ${kanji.char}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _isLearnMode ? AppColors.cyan : AppColors.pink,
                side: BorderSide(color: _isLearnMode ? AppColors.cyan : AppColors.pink, width: 1.5),
                backgroundColor: AppColors.surfaceElevated,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => setState(() => _isLearnMode = !_isLearnMode),
              icon: Icon(_isLearnMode ? Icons.edit : Icons.school, size: 16),
              label: Text(_isLearnMode ? 'Practice Mode' : 'Learn Mode', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    Text(
                      kanji.char,
                      style: const TextStyle(fontSize: 68, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
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
                          if (kanji.jlpt != null) ...[
                            const SizedBox(height: 6),
                            Text('JLPT: N${kanji.jlpt == 4 ? "5" : kanji.jlpt == 3 ? "4" : kanji.jlpt == 2 ? "3/2" : "1"}',
                                style: const TextStyle(color: AppColors.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
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

  Widget _buildPracticeMode(Kanji kanji) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final canvasSize = (screenHeight * 0.35).clamp(200.0, 300.0);

    return SingleChildScrollView(
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
                    Text(
                      kanji.meanings,
                      style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kanji.readings,
                      style: const TextStyle(fontSize: 16, color: AppColors.amber, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (_showAnswer) ...[
                      Text(
                        kanji.char,
                        style: const TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                    ],
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
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _showAnswer = !_showAnswer);
                      },
                      icon: Icon(_showAnswer ? Icons.visibility_off : Icons.visibility, size: 16),
                      label: Text(_showAnswer ? 'Hide Guide' : 'Show Guide'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: const BorderSide(color: AppColors.borderLight, width: 1.5),
                        backgroundColor: AppColors.surfaceElevated,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildRadicals(kanji),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
