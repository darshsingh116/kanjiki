import 'dart:async';
import 'package:flutter/material.dart';
import '../models/kanji.dart';
import '../services/db_service.dart';
import 'practice.dart';

class DictionaryScreen extends StatefulWidget {
  final int? initialJlpt;

  const DictionaryScreen({super.key, this.initialJlpt});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {

  String _hiraToKata(String s) {
    return String.fromCharCodes(s.runes.map((int rune) {
      if (rune >= 0x3041 && rune <= 0x3096) {
        return rune + 0x0060;
      }
      return rune;
    }));
  }

  String _kataToHira(String s) {
    return String.fromCharCodes(s.runes.map((int rune) {
      if (rune >= 0x30A1 && rune <= 0x30F6) {
        return rune - 0x0060;
      }
      return rune;
    }));
  }

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Kanji> _results = [];
  bool _isLoading = false;
  int? _selectedJlpt;

  final Set<int> _selectedKanjiIds = {};
  bool _selectionMode = false;

  Future<void> _search() async {
    setState(() => _isLoading = true);
    final q = _searchController.text.trim();

    String where = '';
    List<dynamic> args = [];

    if (q.isNotEmpty) {
      final hira = _kataToHira(q);
      final kata = _hiraToKata(q);
      where += '(char LIKE ? OR meanings LIKE ? OR readings LIKE ? OR readings LIKE ? OR readings LIKE ?)';
      args.addAll(['%$q%', '%$q%', '%$q%', '%$hira%', '%$kata%']);
    }

    if (_selectedJlpt != null) {
      if (where.isNotEmpty) where += ' AND ';
      where += 'jlpt = ?';
      // Kanjidic2 uses the old 4-level JLPT system (4=N5, 3=N4, 2=N3/N2, 1=N1)
      int dbJlpt = _selectedJlpt!;
      if (_selectedJlpt == 5) dbJlpt = 4;
      else if (_selectedJlpt == 4) dbJlpt = 3;
      else if (_selectedJlpt == 3) dbJlpt = 2; // Old level 2 covers N3 and N2
      else if (_selectedJlpt == 2) dbJlpt = 2;
      else if (_selectedJlpt == 1) dbJlpt = 1;
      
      args.add(dbJlpt);
    }

    if (where.isEmpty) {
      where = '1=1'; // return all if empty
    }

    final res = await DbService.db
        .query('kanji', where: where, whereArgs: args.isEmpty ? null : args, orderBy: 'jlpt IS NULL, jlpt DESC, id ASC', limit: 100);
    setState(() {
      _results = res.map((m) => Kanji.fromMap(m)).toList();
      _isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedJlpt = widget.initialJlpt;
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showDeckSelectionDialog() async {
    final decks = await DbService.getDecks();

    if (!mounted) return;

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Add to Deck'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: decks.length + 1,
                itemBuilder: (context, i) {
                  if (i == decks.length) {
                    return ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Create New Deck'),
                      onTap: () {
                        Navigator.pop(context);
                        _showCreateDeckDialog();
                      },
                    );
                  }
                  final deck = decks[i];
                  return ListTile(
                    title: Text(deck['name']),
                    onTap: () async {
                      await DbService.addCardsToDeck(
                          deck['id'].toString(), _selectedKanjiIds.toList());
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Added  cards to !')),
                        );
                        setState(() {
                          _selectionMode = false;
                          _selectedKanjiIds.clear();
                        });
                      }
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              )
            ],
          );
        });
  }

  void _showCreateDeckDialog() {
    final tc = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('New Deck'),
              content: TextField(
                controller: tc,
                decoration: const InputDecoration(hintText: 'Deck name'),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (tc.text.isNotEmpty) {
                      final newId = await DbService.createDeck(tc.text.trim());
                      await DbService.addCardsToDeck(
                          newId, _selectedKanjiIds.toList());
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Created deck and added  cards!')),
                        );
                        setState(() {
                          _selectionMode = false;
                          _selectedKanjiIds.clear();
                        });
                      }
                    }
                  },
                  child: const Text('Create & Add'),
                )
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '\ Selected' : 'Dictionary'),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _selectionMode = false;
                  _selectedKanjiIds.clear();
                }),
              )
            : null,
        actions: [
          if (_selectionMode && _selectedKanjiIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_to_photos),
              tooltip: 'Add to Deck',
              onPressed: _showDeckSelectionDialog,
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search English, Kanji, or Kana...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (text) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        _search();
                      });
                    },
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<int?>(
                  value: _selectedJlpt,
                  hint: const Text('JLPT'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Any JLPT')),
                    DropdownMenuItem(value: 5, child: Text('N5')),
                    DropdownMenuItem(value: 4, child: Text('N4')),
                    DropdownMenuItem(value: 3, child: Text('N3')),
                    DropdownMenuItem(value: 2, child: Text('N2')),
                    DropdownMenuItem(value: 1, child: Text('N1')),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedJlpt = val);
                    _search();
                  },
                )
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final k = _results[i];
                  final isSelected = _selectedKanjiIds.contains(k.id);

                  String displayJlpt = "?";
                  if (k.jlpt == 4) displayJlpt = "5";
                  else if (k.jlpt == 3) displayJlpt = "4";
                  else if (k.jlpt == 2) displayJlpt = "3/2";
                  else if (k.jlpt == 1) displayJlpt = "1";

                  return ListTile(
                    leading: _selectionMode
                        ? Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedKanjiIds.add(k.id);
                                } else {
                                  _selectedKanjiIds.remove(k.id);
                                  if (_selectedKanjiIds.isEmpty) {
                                    _selectionMode = false;
                                  }
                                }
                              });
                            },
                          )
                        : Text(k.char, style: const TextStyle(fontSize: 32)),
                    title: Text(_selectionMode
                        ? '${k.char}  ${k.meanings}'
                        : k.meanings),
                    subtitle: Text('${k.readings} | JLPT N$displayJlpt'),
                    onLongPress: () {
                      setState(() {
                        _selectionMode = true;
                        _selectedKanjiIds.add(k.id);
                      });
                    },
                    onTap: () {
                      if (_selectionMode) {
                        setState(() {
                          if (isSelected) {
                            _selectedKanjiIds.remove(k.id);
                            if (_selectedKanjiIds.isEmpty) {
                              _selectionMode = false;
                            }
                          } else {
                            _selectedKanjiIds.add(k.id);
                          }
                        });
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PracticeScreen(kanji: k),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            )
        ],
      ),
    );
  }
}
