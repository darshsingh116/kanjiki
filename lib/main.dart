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

    // Logged in or Guest mode -> Home screen directly
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'KanjiKi',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: HomeScreen(
        onSignOut: _handleSignOut,
        onSignIn: () => setState(() => _isGuestMode = false),
      ),
    );
  }
}


