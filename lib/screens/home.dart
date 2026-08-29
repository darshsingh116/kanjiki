import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/supabase_service.dart';
import 'dictionary.dart';
import 'deck_browser.dart';
import 'review_screen.dart';
import 'deck_options.dart';
import 'profile_screen.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSignOut;
  final VoidCallback? onSignIn;

  const HomeScreen({
    super.key,
    this.onSignOut,
    this.onSignIn,
  });

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

  String _getMaskedEmail(String rawEmail) {
    if (!rawEmail.contains('@')) return rawEmail;
    final parts = rawEmail.split('@');
    final username = parts[0];
    final domain = parts[1];
    if (username.isEmpty) return rawEmail;
    final firstChar = username[0];
    final int maskLength = username.length > 1 ? username.length - 1 : 4;
    final stars = '*' * maskLength;
    return '$firstChar$stars@$domain';
  }

  Future<void> _loadData() async {
    try {
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

      if (mounted) {
        setState(() {
          _decks = decksWithStats;
          _jlptCounts = counts;
          _hasPendingSync = pendingSync;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading home screen data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showAddDeckOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
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
                const Text(
                  'Add New Deck',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.pop(context);
                    _createNewDeckPrompt();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppStyles.neoCardDecoration(
                      bg: AppColors.surfaceElevated,
                      borderColor: AppColors.borderLight,
                      radius: 12,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_box, color: AppColors.primaryLight, size: 24),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Create Custom Deck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('Build your own study list of kanji cards', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await DbService.importDatabase();
                      _loadData();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup imported successfully!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Import failed: $e')),
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: AppStyles.neoCardDecoration(
                      bg: AppColors.surfaceElevated,
                      borderColor: AppColors.borderLight,
                      radius: 12,
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.file_download, color: AppColors.green, size: 24),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Import Backup (.ktan)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('Restore an exported database backup file', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _createNewDeckPrompt() {
    final TextEditingController nameCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border, width: 2),
          ),
          title: const Text('Create New Deck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameCtl,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. JLPT N3 Verbs, Common Kanji',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
                if (nameCtl.text.trim().isNotEmpty) {
                  await DbService.createDeck(nameCtl.text.trim());
                  if (context.mounted) Navigator.pop(context);
                  _loadData();
                }
              },
              child: const Text('Create Deck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDeckOptions(Map<String, dynamic> deck) {
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
                Row(
                  children: [
                    const Icon(Icons.style, color: AppColors.cyan, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        deck['name'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: AppColors.border),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.format_list_bulleted, color: AppColors.cyan),
                  title: const Text('Browse & Edit Cards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DeckBrowserScreen(deck: deck)),
                    ).then((_) => _loadData());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune, color: AppColors.primaryLight),
                  title: const Text('Deck Settings & Limits', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DeckOptionsScreen(deck: deck)),
                    ).then((_) => _loadData());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.red),
                  title: const Text('Delete Deck', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete "${deck['name']}"?'),
                        content: const Text('This will delete this deck and all progress for its cards.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await DbService.deleteDeck(deck['id'].toString());
                      _loadData();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJlptDrawerItem(BuildContext context, int modernLevel, String label) {
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.pop(context);
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  backgroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border, width: 2),
                  ),
                  title: Text('Create $label Deck?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  content: Text(
                    'This creates a preset deck named "$label" with $totalKanji kanji.',
                    style: const TextStyle(color: AppColors.textSecondary),
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
                        Navigator.pop(context);
                        await DbService.createJlptDeck(modernLevel);
                        _loadData();
                      },
                      child: const Text('Add Deck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                );
              },
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'N$modernLevel',
                    style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                Text('$totalKanji kanji', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(width: 6),
                const Icon(Icons.add_circle_outline, size: 18, color: AppColors.cyan),
              ],
            ),
          ),
        ),
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

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primaryLight, width: 1.5),
              ),
              child: const Text('漢字', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            const Text(
              'KanjiKi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _hasPendingSync,
              backgroundColor: AppColors.amber,
              child: const Icon(Icons.sync, size: 22),
            ),
            tooltip: 'Sync Data',
            onPressed: () {
              SyncService.syncData(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 24),
            tooltip: 'Add Deck',
            onPressed: _showAddDeckOptions,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: Builder(
          builder: (drawerCtx) {
            final isAuthed = SupabaseService.isAuthenticated;
            final user = isAuthed ? SupabaseService.currentUser : null;
            final String rawEmail = user?.email ?? 'Guest User';
            final String maskedEmail = isAuthed ? _getMaskedEmail(rawEmail) : 'Offline Mode';
            final String initial = rawEmail.isNotEmpty ? rawEmail[0].toUpperCase() : 'G';

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceElevated,
                    border: Border(
                      bottom: BorderSide(color: AppColors.border, width: 2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryLight, width: 2),
                          boxShadow: AppStyles.neoShadow(offset: 2),
                        ),
                        child: const Center(
                          child: Text('気', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'KanjiKi 漢字気',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Spaced Repetition & Stroke Master',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // My Profile & Account Menu Item
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Material(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(drawerCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(
                              onSignOut: widget.onSignOut,
                              onSignIn: widget.onSignIn,
                            ),
                          ),
                        ).then((_) => _loadData());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isAuthed ? AppColors.primary : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isAuthed ? AppColors.primaryLight : AppColors.border, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('My Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(
                                    maskedEmail,
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: isAuthed ? AppColors.cyan : AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Dictionary & Search Menu Item
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Material(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(drawerCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DictionaryScreen()),
                        ).then((_) => _loadData());
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search, color: AppColors.cyan, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Dictionary & Search', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    'JLPT PRESET DECKS',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.8),
                  ),
                ),
                _buildJlptDrawerItem(context, 5, 'JLPT N5 (Beginner)'),
                _buildJlptDrawerItem(context, 4, 'JLPT N4 (Basic)'),
                _buildJlptDrawerItem(context, 3, 'JLPT N3 (Intermediate)'),
                _buildJlptDrawerItem(context, 2, 'JLPT N2 (Upper Int)'),
                _buildJlptDrawerItem(context, 1, 'JLPT N1 (Advanced)'),
                const SizedBox(height: 8),
                const Divider(color: AppColors.border),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    'BACKUP & DATA',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMuted, fontSize: 11, letterSpacing: 0.8),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined, color: AppColors.green, size: 20),
                  title: const Text('Export Backup (.ktan)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(drawerCtx);
                    await DbService.exportDatabase();
                  },
                ),
              ],
            );
          },
        ),
      ),
      body: _decks.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppStyles.neoCardDecoration(
                    bg: AppColors.surface,
                    borderColor: AppColors.border,
                    radius: 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.primaryLight, width: 2),
                        ),
                        child: const Icon(Icons.library_books, color: AppColors.primaryLight, size: 28),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Decks Found',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a custom deck or choose from JLPT N5–N1 presets in the menu.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _showAddDeckOptions,
                        style: AppStyles.neoButtonStyle(
                          bg: AppColors.primary,
                          borderColor: AppColors.primaryLight,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create Your First Deck', style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 32, top: 12, left: 14, right: 14),
              itemCount: _decks.length,
              itemBuilder: (context, index) {
                final deck = _decks[index];
                int newCount = deck['new'] ?? 0;
                int learningCount = deck['learning'] ?? 0;
                int reviewCount = deck['review'] ?? 0;
                String frontMode = deck['front_mode'] ?? 'both';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 7),
                  decoration: AppStyles.neoCardDecoration(
                    bg: AppColors.surface,
                    borderColor: AppColors.border,
                    radius: 16,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReviewScreen(deckId: deck['id'].toString()),
                        ),
                      ).then((_) => _loadData());
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  deck['name'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border, width: 1),
                                ),
                                child: Text(
                                  frontMode == 'kanji'
                                      ? 'Kanji Front'
                                      : frontMode == 'meaning'
                                          ? 'Meaning Front'
                                          : 'Standard',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary, size: 20),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showDeckOptions(deck),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Anki SRS Status Counters
                          Row(
                            children: [
                              _buildCounterPill('New', newCount, AppColors.srsNew),
                              const SizedBox(width: 8),
                              _buildCounterPill('Learn', learningCount, AppColors.srsLearn),
                              const SizedBox(width: 8),
                              _buildCounterPill('Due', reviewCount, AppColors.srsReview),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Study', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold, fontSize: 12)),
                                    SizedBox(width: 4),
                                    Icon(Icons.play_arrow, size: 14, color: AppColors.primaryLight),
                                  ],
                                ),
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

  Widget _buildCounterPill(String label, int count, Color color) {
    bool hasCards = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: hasCards ? color.withValues(alpha: 0.15) : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasCards ? color.withValues(alpha: 0.8) : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: hasCards ? color : AppColors.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: hasCards ? color.withValues(alpha: 0.8) : AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
