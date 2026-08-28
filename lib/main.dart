import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kanjiapp/screens/auth_screen.dart';
import 'package:kanjiapp/screens/home.dart';
import 'package:kanjiapp/services/db_service.dart';
import 'package:kanjiapp/services/env_service.dart';
import 'package:kanjiapp/services/supabase_service.dart';
import 'package:kanjiapp/services/sync_service.dart';
import 'package:kanjiapp/theme/app_theme.dart';
import 'package:kanjiapp/widgets/profile_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force Flutter framework errors to be printed.
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
    // ignore: avoid_print
    debugPrint('FLUTTER_ERROR: ${details.exceptionAsString()}');
  };

  await DbService.init();
  await EnvService.loadDotEnv();
  await SupabaseService.init();

  runApp(const KanjiKiApp());
}

class KanjiKiApp extends StatefulWidget {
  const KanjiKiApp({super.key});

  @override
  State<KanjiKiApp> createState() => _KanjiKiAppState();
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class _KanjiKiAppState extends State<KanjiKiApp> {
  StreamSubscription<AuthState>? _authSub;

  bool _isAuthenticated = SupabaseService.isAuthenticated;
  bool _isGuestMode = !SupabaseService.isInitialized;
  bool _didInitialSync = false;

  String? get _userLabel {
    if (!SupabaseService.isAuthenticated) return null;
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) return null;
      final email = user.email;
      return (email != null && email.trim().isNotEmpty) ? email.trim() : user.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> _maybeInitialSync({bool force = false}) async {
    if (!mounted) return;
    if (!force && _didInitialSync) return;
    if (!SupabaseService.isAuthenticated) return;

    _didInitialSync = true;

    try {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            title: const Row(
              children: [
                Icon(Icons.sync, color: AppColors.primary),
                SizedBox(width: 10),
                Text("Sync with Cloud?", style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              "Would you like to sync your decks and spaced-repetition progress with the cloud now?",
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Later", style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: AppStyles.neoButtonStyle(
                  bg: AppColors.primary,
                  borderColor: AppColors.primaryLight,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  SyncService.syncData(context);
                },
                child: const Text("Sync Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Sync prompt error: $e");
    }
  }

  @override
  void initState() {
    super.initState();

    _isAuthenticated = SupabaseService.isAuthenticated;

    if (SupabaseService.isInitialized) {
      _authSub = SupabaseService.client.auth.onAuthStateChange.listen((event) async {
        final authed = event.session?.user != null;
        if (!mounted) return;

        setState(() {
          _isAuthenticated = authed;
          if (!authed) _didInitialSync = false;
        });

        if (authed) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            await _maybeInitialSync();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _handleSignOut() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sync_$userId');
    }
    try {
      await SupabaseService.client.auth.signOut();
    } catch (_) {}
    await DbService.clearUserData();
    if (!mounted) return;
    setState(() {
      _didInitialSync = false;
      _isGuestMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userLabel = _userLabel;
    final appTheme = buildAppTheme();

    if (!_isAuthenticated && !_isGuestMode) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        title: 'KanjiKi',
        theme: appTheme,
        debugShowCheckedModeBanner: false,
        home: SafeArea(
          child: Container(
            color: AppColors.bgDark,
            child: AuthScreen(
              onContinueAsGuest: () {
                setState(() => _isGuestMode = true);
              },
            ),
          ),
        ),
      );
    }

    final String initialChar = (_isAuthenticated && userLabel != null && userLabel.isNotEmpty)
        ? userLabel[0].toUpperCase()
        : 'G';

    // Logged in or Guest mode -> Home + sleek neobrutalist header
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'KanjiKi',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(
          children: [
            // Top Neobrutalist Profile Bar
            Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1.5),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      // Clickable Profile Avatar & Badge
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          ProfileBottomSheet.show(
                            context,
                            onSignOut: _handleSignOut,
                            onSignIn: () => setState(() => _isGuestMode = false),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _isAuthenticated ? AppColors.primary : AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _isAuthenticated ? AppColors.primaryLight : AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  initialChar,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _isAuthenticated ? (userLabel ?? 'User') : 'Guest Explorer',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.textMuted),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: _isAuthenticated ? AppColors.green : AppColors.amber,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isAuthenticated ? 'Cloud Synced' : 'Offline Mode',
                                      style: TextStyle(
                                        color: _isAuthenticated ? AppColors.green : AppColors.amber,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Action Button on Top Bar
                      if (_isAuthenticated)
                        OutlinedButton.icon(
                          onPressed: () {
                            SyncService.syncData(context);
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceElevated,
                            side: const BorderSide(color: AppColors.borderLight, width: 1.5),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.sync, size: 14, color: AppColors.cyan),
                          label: const Text(
                            'Sync',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          icon: const Icon(Icons.bolt, size: 14, color: Colors.white),
                          onPressed: () {
                            setState(() => _isGuestMode = false);
                          },
                          style: AppStyles.neoButtonStyle(
                            bg: AppColors.primary,
                            borderColor: AppColors.primaryLight,
                            radius: 8,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          label: const Text(
                            'Sign In',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.surface,
                onRefresh: () => _maybeInitialSync(force: true),
                child: const HomeScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


