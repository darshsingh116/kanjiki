import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

class ProfileBottomSheet extends StatefulWidget {
  final VoidCallback onSignOut;
  final VoidCallback onSignIn;

  const ProfileBottomSheet({
    super.key,
    required this.onSignOut,
    required this.onSignIn,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onSignOut,
    required VoidCallback onSignIn,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileBottomSheet(
        onSignOut: onSignOut,
        onSignIn: onSignIn,
      ),
    );
  }

  @override
  State<ProfileBottomSheet> createState() => _ProfileBottomSheetState();
}

class _ProfileBottomSheetState extends State<ProfileBottomSheet> {
  int _totalDecks = 0;
  int _totalCards = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final decks = await DbService.getDecks();
      final stats = await DbService.getStats();
      if (mounted) {
        setState(() {
          _totalDecks = decks.length;
          _totalCards = stats['total'] ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthed = SupabaseService.isAuthenticated;
    final user = isAuthed ? SupabaseService.currentUser : null;
    final String email = user?.email ?? 'Guest User';
    final String initial = email.isNotEmpty ? email[0].toUpperCase() : 'G';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppColors.border, width: 2),
        boxShadow: AppStyles.neoShadow(offset: 4),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Profile Header Row
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isAuthed ? AppColors.primary : AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isAuthed ? AppColors.primaryLight : AppColors.border, width: 2),
                    boxShadow: AppStyles.neoShadow(offset: 2),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
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
                        isAuthed ? 'Cloud Account' : 'Offline / Guest Mode',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isAuthed ? AppColors.green : AppColors.amber).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isAuthed ? AppColors.green : AppColors.amber, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAuthed ? Icons.cloud_done : Icons.cloud_off,
                        size: 14,
                        color: isAuthed ? AppColors.green : AppColors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAuthed ? 'Synced' : 'Local',
                        style: TextStyle(
                          color: isAuthed ? AppColors.green : AppColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // User Study Stats Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppStyles.neoCardDecoration(
                bg: AppColors.surfaceElevated,
                borderColor: AppColors.border,
                radius: 14,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _loading ? '-' : '$_totalDecks',
                          style: const TextStyle(
                            color: AppColors.cyan,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Decks',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1.5, height: 36, color: AppColors.border),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          _loading ? '-' : '$_totalCards',
                          style: const TextStyle(
                            color: AppColors.pink,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Total Cards',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1.5, height: 36, color: AppColors.border),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          '100%',
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Offline Ready',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            if (isAuthed) ...[
              ElevatedButton.icon(
                style: AppStyles.neoButtonStyle(
                  bg: AppColors.primary,
                  borderColor: AppColors.primaryLight,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  SyncService.syncData(context);
                },
                icon: const Icon(Icons.sync, size: 18),
                label: const Text('Sync with Cloud', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign out of KanjiKi?'),
                      content: const Text(
                        'This will clear the current local cached session. Your cloud backup remains safe in Supabase.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    widget.onSignOut();
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              ElevatedButton.icon(
                style: AppStyles.neoButtonStyle(
                  bg: AppColors.primary,
                  borderColor: AppColors.primaryLight,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onSignIn();
                },
                icon: const Icon(Icons.login, size: 18),
                label: const Text('Sign In to Enable Cloud Sync', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
