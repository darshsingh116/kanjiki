import 'package:flutter/material.dart';
import '../services/db_service.dart';
import 'dictionary.dart';
import 'deck_browser.dart';
import 'review_screen.dart';
import 'deck_options.dart';

import '../services/sync_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _hasPendingSync = false;
  List<Map<String, dynamic>> _decks = [];
  Map<int, int> _jlptCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    SyncService.syncNotifier.addListener(_onSyncComplete);
  }

  @override
  void dispose() {
    SyncService.syncNotifier.removeListener(_onSyncComplete);
    super.dispose();
  }

  void _onSyncComplete() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final decks = await DbService.getDecks();
    final counts = await DbService.getJlptCounts();
    final pendingSync = await SyncService.hasPendingLocalChanges();

    List<Map<String, dynamic>> decksWithStats = [];
    for (var d in decks) {
      final deckStats = await DbService.getStats(deckId: d['id'].toString());
      decksWithStats.add({
        ...d,
        'learning': deckStats['learning'],
        'review': deckStats['review'],
        'due': deckStats['due'],
        'new': deckStats['new'],
        'total': deckStats['total'],
      });
    }

    setState(() {
      _decks = decksWithStats;
      _jlptCounts = counts;
      _hasPendingSync = pendingSync;
      _isLoading = false;
    });
  }

  void _showAddDeckOptions() {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF2D2D44),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add, color: Colors.blueAccent),
                  title: const Text('Create Empty Deck',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    _createNewDeckPrompt();
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.download, color: Colors.greenAccent),
                  title: const Text('Import Deck Backup',
                      style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await DbService.importDatabase();
                      _loadData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Backup Imported!')));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Import failed: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
          );
        });
  }

  void _createNewDeckPrompt() {
    final TextEditingController nameCtl = TextEditingController();
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2D2D44),
            title:
                const Text('New Deck', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: nameCtl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Deck Name',
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child:
                    const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () async {
                  if (nameCtl.text.trim().isNotEmpty) {
                    await DbService.createDeck(nameCtl.text.trim());
                    if (context.mounted) Navigator.pop(context);
                    _loadData();
                  }
                },
                child:
                    const Text('Create', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
  }

  void _showDeckOptions(Map<String, dynamic> deck) {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF2D2D44),
        builder: (context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(deck['name'],
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const Divider(color: Colors.grey),
                ListTile(
                  leading: const Icon(Icons.list, color: Colors.white),
                  title: const Text('Browse / Edit Cards',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                     Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DeckBrowserScreen(deck: deck)))
                        .then((_) => _loadData());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.white),
                  title: const Text('Options',
                      style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DeckOptionsScreen(deck: deck)))
                        .then((_) => _loadData());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: const Text('Delete Deck',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    await DbService.deleteDeck(deck['id'].toString());
                    _loadData();
                  },
                ),
              ],
            ),
          );
        });
  }

  Widget _buildJlptDrawerItem(
      BuildContext context, int modernLevel, String label) {
    int dbJlpt = modernLevel;
    if (modernLevel == 5) {
      dbJlpt = 4;
    } else if (modernLevel == 4) {
      dbJlpt = 3;
    } else if (modernLevel == 3) {
      dbJlpt = 2;
    } else if (modernLevel == 2) {
      dbJlpt = 2;
    } else if (modernLevel == 1) {
      dbJlpt = 1;
    }

    int totalKanji = _jlptCounts[dbJlpt] ?? 0;

    return ListTile(
      leading: const Icon(Icons.school),
      title: Text(label),
      trailing: Text('$totalKanji', style: const TextStyle(color: Colors.grey)),
      onTap: () {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2D2D44),
              title: Text('Add $label Deck?',
                  style: const TextStyle(color: Colors.white)),
              content: Text(
                  'This creates a deck named "$label" with $totalKanji kanji.',
                  style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await DbService.createJlptDeck(modernLevel);
                    _loadData();
                  },
                  child: const Text('Add Deck',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          backgroundColor: Color(0xFF121212),
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('KanjiKi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E2C),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _hasPendingSync,
              backgroundColor: Colors.red,
              child: const Icon(Icons.sync),
            ),
            tooltip: 'Sync Data',
            onPressed: () {
              SyncService.syncData(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddDeckOptions,
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E2C),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2D2D44), Color(0xFF1E1E2C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(Icons.school, size: 48, color: Colors.blueAccent),
                  SizedBox(height: 12),
                  Text(
                    'KanjiKi',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListTile(
              iconColor: Colors.white,
              textColor: Colors.white,
              leading: const Icon(Icons.search),
              title: const Text('Dictionary & Search'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                ).then((_) => _loadData());
              },
            ),
            const Divider(color: Colors.white24),
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 8.0),
              child: Text('Presets',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white54)),
            ),
            _buildJlptDrawerItem(context, 5, 'JLPT N5'),
            _buildJlptDrawerItem(context, 4, 'JLPT N4'),
            _buildJlptDrawerItem(context, 3, 'JLPT N3'),
            _buildJlptDrawerItem(context, 2, 'JLPT N2'),
            _buildJlptDrawerItem(context, 1, 'JLPT N1'),
            const Divider(color: Colors.white24),
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 8.0),
              child: Text('Data',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white54)),
            ),
            ListTile(
                iconColor: Colors.white,
                textColor: Colors.white,
                leading: const Icon(Icons.upload),
                title: const Text('Export Backup (.ktan)'),
                onTap: () async {
                  Navigator.pop(context);
                  await DbService.exportDatabase();
                }),
          ],
        ),
      ),
      body: _decks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No decks yet!',
                      style: TextStyle(color: Colors.white54, fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddDeckOptions,
                    icon: const Icon(Icons.add),
                    label: const Text('Create a Deck'),
                  )
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 24, top: 8),
              itemCount: _decks.length,
              itemBuilder: (context, index) {
                final deck = _decks[index];
                int newCount = deck['new'] ?? 0;
                int learningCount = deck['learning'] ?? 0;
                int reviewCount = deck['review'] ?? 0;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFF1E1E2C),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      // Start Review
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReviewScreen(
                            deckId: deck['id'].toString(),
                          ),
                        ),
                      ).then((_) => _loadData());
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(deck['name'],
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Anki Stats: Blue (New) | Red (Learning) | Green (Review)
                              _buildStatBadge(newCount, const Color(0xFF00A8FF)),
                              const SizedBox(width: 8),
                              _buildStatBadge(learningCount, const Color(0xFFFF5252)),
                              const SizedBox(width: 8),
                              _buildStatBadge(reviewCount, const Color(0xFF4CAF50)),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.more_vert, color: Colors.white54),
                                onPressed: () => _showDeckOptions(deck),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatBadge(int count, Color baseColor) {
    bool isActive = count > 0;
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? baseColor.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '$count',
          style: TextStyle(
            color: isActive ? baseColor : baseColor.withValues(alpha: 0.3),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
