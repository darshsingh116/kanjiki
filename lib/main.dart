import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kanjiapp/screens/auth_screen.dart';
import 'package:kanjiapp/screens/home.dart';
import 'package:kanjiapp/services/db_service.dart';
import 'package:kanjiapp/services/env_service.dart';
import 'package:kanjiapp/services/supabase_service.dart';
import 'package:kanjiapp/services/sync_service.dart';
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
            backgroundColor: const Color(0xFF2D2D44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.sync, color: Colors.blueAccent),
                SizedBox(width: 10),
                Text("Sync with Cloud?", style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: const Text(
              "Would you like to sync your decks and spaced-repetition progress with the cloud now?",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Later", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                onPressed: () {
                  Navigator.pop(ctx);
                  SyncService.syncData(context);
                },
                child: const Text("Sync Now", style: TextStyle(color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    final userLabel = _userLabel;

    final baseTheme = ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
    );

    if (!_isAuthenticated && !_isGuestMode) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        title: 'KanjiKi',
        theme: baseTheme,
        debugShowCheckedModeBanner: false,
        home: SafeArea(
          child: Container(
            color: const Color(0xFF121212),
            child: AuthScreen(
              onContinueAsGuest: () {
                setState(() => _isGuestMode = true);
              },
            ),
          ),
        ),
      );
    }

    // Logged in or Guest mode -> Home + user status header
    return MaterialApp(
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'KanjiKi',
      theme: baseTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Column(
          children: [
            Material(
              color: const Color(0xFF1E1E2C),
              elevation: 0,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isAuthenticated
                            ? 'Signed in as: ${userLabel ?? ''}'
                            : 'Offline / Guest Mode',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isAuthenticated)
                      OutlinedButton(
                        onPressed: () async {
                          final userId = SupabaseService.client.auth.currentUser?.id;
                          if (userId != null) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.remove('last_sync_$userId');
                          }
                          await SupabaseService.client.auth.signOut();
                          await DbService.clearUserData();
                          if (!mounted) return;
                          setState(() {
                            _didInitialSync = false;
                            _isGuestMode = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blueAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text(
                          'Sign out',
                          style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                        ),
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.cloud_sync, size: 16, color: Colors.blueAccent),
                        onPressed: () {
                          setState(() => _isGuestMode = false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blueAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        label: const Text(
                          'Sign In for Cloud Sync',
                          style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: RefreshIndicator(
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


