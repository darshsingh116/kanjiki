import 'dart:async';
import 'package:flutter/material.dart';
import '../models/kanji.dart';
import '../services/db_service.dart';
import 'practice.dart';
import '../theme/app_theme.dart';

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
      int dbJlpt = _selectedJlpt!;
      if (_selectedJlpt == 5) {
        dbJlpt = 4;
      } else if (_selectedJlpt == 4) {
        dbJlpt = 3;
      } else if (_selectedJlpt == 3) {
        dbJlpt = 2;
      } else if (_selectedJlpt == 2) {
        dbJlpt = 2;
      } else if (_selectedJlpt == 1) {
        dbJlpt = 1;
      }

      args.add(dbJlpt);
    }

    if (where.isEmpty) {
      where = '1=1';
    }

    final res = await DbService.db.query(
      'kanji',
      where: where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'jlpt IS NULL, jlpt DESC, id ASC',
      limit: 100,
    );
    if (mounted) {
      setState(() {
        _results = res.map((m) => Kanji.fromMap(m)).toList();
        _isLoading = false;
      });
    }
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.border, width: 2),
            boxShadow: AppStyles.neoShadow(offset: 4),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add ${_selectedKanjiIds.length} Kanji to Deck',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: decks.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      if (i == decks.length) {
                        return OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.cyan,
                            side: const BorderSide(color: AppColors.borderLight, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create New Deck'),
                          onPressed: () {
                            Navigator.pop(context);
                            _showCreateDeckDialog();
                          },
                        );
                      }
                      final deck = decks[i];
                      return Container(
                        decoration: AppStyles.neoCardDecoration(
                          bg: AppColors.surfaceElevated,
                          borderColor: AppColors.border,
                          radius: 10,
                          withShadow: false,
                        ),
                        child: ListTile(
                          title: Text(
                            deck['name'],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          trailing: const Icon(Icons.add_circle_outline, color: AppColors.primaryLight, size: 20),
                          onTap: () async {
                            final count = _selectedKanjiIds.length;
                            await DbService.addCardsToDeck(
                              deck['id'].toString(),
                              _selectedKanjiIds.toList(),
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added $count cards to "${deck['name']}"!')),
                              );
                              setState(() {
                                _selectionMode = false;
                                _selectedKanjiIds.clear();
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateDeckDialog() {
    final tc = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 2),
        ),
        title: const Text('Create New Deck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: tc,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Deck name',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: AppStyles.neoButtonStyle(
              bg: AppColors.primary,
              borderColor: AppColors.primaryLight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              if (tc.text.trim().isNotEmpty) {
                final count = _selectedKanjiIds.length;
                final newId = await DbService.createDeck(tc.text.trim());
                await DbService.addCardsToDeck(newId, _selectedKanjiIds.toList());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Created "${tc.text.trim()}" and added $count cards!')),
                  );
                  setState(() {
                    _selectionMode = false;
                    _selectedKanjiIds.clear();
                  });
                }
              }
            },
            child: const Text('Create & Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          _selectionMode ? '${_selectedKanjiIds.length} Selected' : 'Kanji Dictionary',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
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
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ElevatedButton.icon(
                style: AppStyles.neoButtonStyle(
                  bg: AppColors.primary,
                  borderColor: AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  radius: 8,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add to Deck', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: _showDeckSelectionDialog,
              ),
            )
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1.5)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search English, Kanji, or Kana...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppColors.cyan, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              _search();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (text) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 250), () {
                      _search();
                    });
                  },
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 10),
                // JLPT Filter Pills Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildJlptFilterChip(null, 'All JLPT'),
                      _buildJlptFilterChip(5, 'N5'),
                      _buildJlptFilterChip(4, 'N4'),
                      _buildJlptFilterChip(3, 'N3'),
                      _buildJlptFilterChip(2, 'N2'),
                      _buildJlptFilterChip(1, 'N1'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_results.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('No Kanji Found', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Try searching with different keywords or JLPT filters', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final k = _results[i];
                  final isSelected = _selectedKanjiIds.contains(k.id);

                  String displayJlpt = "?";
                  if (k.jlpt == 4) {
                    displayJlpt = "5";
                  } else if (k.jlpt == 3) {
                    displayJlpt = "4";
                  } else if (k.jlpt == 2) {
                    displayJlpt = "3/2";
                  } else if (k.jlpt == 1) {
                    displayJlpt = "1";
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: AppStyles.neoCardDecoration(
                      bg: isSelected ? AppColors.primary.withValues(alpha: 0.15) : AppColors.surface,
                      borderColor: isSelected ? AppColors.primary : AppColors.border,
                      radius: 14,
                      withShadow: false,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
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
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            if (_selectionMode)
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Icon(
                                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                  color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
                                ),
                              )
                            else
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    k.char,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    k.meanings,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    k.readings,
                                    style: const TextStyle(
                                      color: AppColors.amber,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'N$displayJlpt',
                                style: const TextStyle(
                                  color: AppColors.cyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildJlptFilterChip(int? level, String label) {
    final bool isSelected = _selectedJlpt == level;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedJlpt = selected ? level : null;
          });
          _search();
        },
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceElevated,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
            width: 1.5,
          ),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}
