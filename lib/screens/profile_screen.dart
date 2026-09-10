import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/kanjiki_logo.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onSignOut;
  final VoidCallback? onSignIn;

  const ProfileScreen({
    super.key,
    this.onSignOut,
    this.onSignIn,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _totalDecks = 0;
  int _totalCards = 0;
  bool _loading = true;
  bool _revealEmail = false;

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

  String _getMaskedEmail(String rawEmail) {
    if (_revealEmail || !rawEmail.contains('@')) return rawEmail;
    final parts = rawEmail.split('@');
    final username = parts[0];
    final domain = parts[1];
    if (username.isEmpty) return rawEmail;
    final firstChar = username[0];
    final int maskLength = username.length > 1 ? username.length - 1 : 4;
    final stars = '*' * maskLength;
    return '$firstChar$stars@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthed = SupabaseService.isAuthenticated;
    final user = isAuthed ? SupabaseService.currentUser : null;
    final String rawEmail = user?.email ?? 'Guest Explorer';
    final String displayedEmail = isAuthed ? _getMaskedEmail(rawEmail) : 'Guest (Offline Storage)';
    final String initial = rawEmail.isNotEmpty ? rawEmail[0].toUpperCase() : 'G';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AppStyles.neoCardDecoration(
                    bg: AppColors.surface,
                    borderColor: AppColors.border,
                    radius: 20,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: isAuthed ? AppColors.primary : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isAuthed ? AppColors.primaryLight : AppColors.borderLight,
                            width: 2.5,
                          ),
                          boxShadow: AppStyles.neoShadow(offset: 3),
                        ),
                        child: Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isAuthed ? 'Cloud Account' : 'Offline / Guest Mode',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Interactive Masked Email Pill
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: isAuthed
                            ? () {
                                setState(() => _revealEmail = !_revealEmail);
                              }
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderLight, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAuthed ? Icons.email_outlined : Icons.person_outline,
                                size: 16,
                                color: AppColors.cyan,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                displayedEmail,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              if (isAuthed) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  _revealEmail ? Icons.visibility_off : Icons.visibility,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isAuthed ? AppColors.green : AppColors.amber).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isAuthed ? AppColors.green : AppColors.amber,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAuthed ? Icons.cloud_done : Icons.cloud_off,
                              size: 16,
                              color: isAuthed ? AppColors.green : AppColors.amber,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isAuthed ? 'Connected to Cloud Sync' : 'Local Storage Only',
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
                ),
                const SizedBox(height: 16),

                // Statistics Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: AppStyles.neoCardDecoration(
                    bg: AppColors.surface,
                    borderColor: AppColors.border,
                    radius: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bar_chart, color: AppColors.cyan, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Study Overview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border, width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _loading ? '-' : '$_totalDecks',
                                    style: const TextStyle(
                                      color: AppColors.cyan,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Total Decks',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border, width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _loading ? '-' : '$_totalCards',
                                    style: const TextStyle(
                                      color: AppColors.pink,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Total Cards',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Account Actions
                if (isAuthed) ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: AppColors.red, width: 1.5),
                      backgroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.border, width: 2),
                          ),
                          title: const Text('Sign Out of KanjiKi?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          content: const Text(
                            'This will log you out on this device. Your data in the cloud is safely preserved.',
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
                      if (confirm == true && mounted) {
                        Navigator.pop(context);
                        widget.onSignOut?.call();
                      }
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Sign Out of Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: AppStyles.neoButtonStyle(
                      bg: AppColors.primary,
                      borderColor: AppColors.primaryLight,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSignIn?.call();
                    },
                    icon: const Icon(Icons.login, size: 18),
                    label: const Text('Sign In / Register for Cloud Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
                const SizedBox(height: 32),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    KanjiKiLogo(size: 24, showShadow: false),
                    SizedBox(width: 8),
                    Text(
                      'KanjiKi • 漢字気 • Spaced Repetition',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
