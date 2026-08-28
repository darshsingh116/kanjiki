import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/kanji.dart';
import '../services/db_service.dart';
import 'card_editor.dart';

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
    setState(() {
      _cards = cards;
      _loading = false;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "New";
    if (date.isBefore(DateTime.now())) return "Due";
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: Text('${widget.deck['name']} - ${_cards.length} Cards', style: const TextStyle(color: Colors.white, fontSize: 18)),    
        backgroundColor: const Color(0xFF2D2D44),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header Row
                Container(
                  color: const Color(0xFF2D2D44),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Row(
                    children: [
                      Expanded(flex: 1, child: Text("Kj", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("Reading", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text("Meaning", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Text("Reps", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("Due", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _cards.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                    itemBuilder: (context, index) {
                      final kanji = _cards[index];
                      // Compact Row Item
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(kanji.char, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  kanji.readings,
                                  style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  kanji.meanings,
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  kanji.reps.toString(),
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  _formatDate(kanji.dueDate),
                                  style: TextStyle(
                                    color: (kanji.dueDate == null || kanji.dueDate!.isBefore(DateTime.now())) 
                                        ? Colors.greenAccent 
                                        : Colors.white54,
                                    fontSize: 13,
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
