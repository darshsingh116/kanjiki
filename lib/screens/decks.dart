import 'package:flutter/material.dart';
import '../services/db_service.dart';
import 'deck_browser.dart';
import 'review_screen.dart';

class DecksScreen extends StatefulWidget {
  const DecksScreen({super.key});

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen> {
  List<Map<String, dynamic>> _decks = [];

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    final decks = await DbService.getDecks();
    setState(() {
      _decks = decks;
    });
  }

  void _showDeckSettings(Map<String, dynamic> deck) {
    String selectedMode = deck['front_mode'] ?? 'kanji';
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('${deck['name']} Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Front Side of Card:'),
                  RadioListTile<String>(
                    title: const Text('Show Kanji'),
                    value: 'kanji',
                    groupValue: selectedMode,
                    onChanged: (val) {
                      setDialogState(() => selectedMode = val!);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Show English (Meaning)'),
                    value: 'english',
                    groupValue: selectedMode,
                    onChanged: (val) {
                      setDialogState(() => selectedMode = val!);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('Show Hiragana/Katakana (Reading)'),
                    value: 'hiragana',
                    groupValue: selectedMode,
                    onChanged: (val) {
                      setDialogState(() => selectedMode = val!);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await DbService.deleteDeck(deck['id'].toString());
                    if (context.mounted) Navigator.pop(context);
                    _loadDecks();
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete Deck'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await DbService.updateDeckMode(deck['id'].toString(), selectedMode);
                    if (context.mounted) Navigator.pop(context);
                    _loadDecks();
                  },
                  child: const Text('Save'),
                )
              ],
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Decks')),
      body: _decks.isEmpty
          ? const Center(
              child:
                  Text('No decks created yet. Go to Dictionary to create one!'))
          : ListView.builder(
              itemCount: _decks.length,
              itemBuilder: (context, i) {
                final deck = _decks[i];
                return ListTile(
                  leading: const Icon(Icons.style),
                  title: Text(deck['name']),
                  subtitle: Text(
                      'Front: ${deck['front_mode']?.toUpperCase() ?? 'KANJI'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.list),
                        tooltip: 'Browse Cards',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DeckBrowserScreen(deck: deck),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => _showDeckSettings(deck),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewScreen(
                                  deckId: deck['id'].toString(),
                                  frontMode: deck['front_mode'] ?? 'kanji'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(
                            deckId: deck['id'].toString(),
                            frontMode: deck['front_mode'] ?? 'kanji'),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
