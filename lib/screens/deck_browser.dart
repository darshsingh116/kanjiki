import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/kanji.dart';
import '../services/db_service.dart';
import 'card_editor.dart';
import '../theme/app_theme.dart';

class DeckBrowserScreen extends StatefulWidget {
  final Map<String, dynamic> deck;

  const DeckBrowserScreen({super.key, required this.deck});

  @override
  State<DeckBrowserScreen> createState() => _DeckBrowserScreenState();
}

class _DeckBrowserScreenState extends State<DeckBrowserScreen> {
  List<Kanji> _cards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    final deckId = widget.deck['id'].toString();
    final cards = await DbService.getCardsForDeck(deckId);
    if (mounted) {
      setState(() {
        _cards = cards;
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "New";
    if (date.isBefore(DateTime.now())) return "Due";
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          '${widget.deck['name']} (${_cards.length})',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _cards.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppStyles.neoCardDecoration(
                        bg: AppColors.surface,
                        borderColor: AppColors.border,
                        radius: 16,
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                          SizedBox(height: 14),
                          Text('Deck is Empty', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Text('Add kanji cards from the Dictionary screen.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Header Row
                    Container(
                      color: AppColors.surfaceElevated,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 1, child: Text("Kanji", style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text("Readings", style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 3, child: Text("Meanings", style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 1, child: Text("Reps", style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text("Status", style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _cards.length,
                        separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                        itemBuilder: (context, index) {
                          final kanji = _cards[index];
                          final isDue = kanji.dueDate != null && kanji.dueDate!.isBefore(DateTime.now());
                          final isNew = kanji.dueDate == null;

                          return InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CardEditorScreen(kanji: kanji),
                                ),
                              );
                              _loadCards();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: Text(kanji.char, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      kanji.readings,
                                      style: const TextStyle(color: AppColors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      kanji.meanings,
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      kanji.reps.toString(),
                                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _formatDate(kanji.dueDate),
                                      style: TextStyle(
                                        color: isDue
                                            ? AppColors.srsLearn
                                            : isNew
                                                ? AppColors.srsNew
                                                : AppColors.srsReview,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
