import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env_service.dart';

class SupabaseService {
  static bool _isInitialized = false;

  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError('Supabase is not initialized. Please provide SUPABASE_URL and SUPABASE_ANON_KEY.');
    }
    return Supabase.instance.client;
  }

  static SupabaseClient? get clientOrNull => _isInitialized ? Supabase.instance.client : null;

  static User? get currentUser {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  static bool get isInitialized => _isInitialized;

  static Future<void> init() async {
    final url = EnvService.get('SUPABASE_URL');
    final anonKey = EnvService.get('SUPABASE_ANON_KEY');

    if (url.isEmpty || anonKey.isEmpty) {
      debugPrint('Supabase credentials not found. App is running in offline/local mode.');
      _isInitialized = false;
      return;
    }

    var cleanedUrl = url.trim();
    cleanedUrl = cleanedUrl.replaceAll('/rest/v1', '');
    cleanedUrl = cleanedUrl.replaceAll(RegExp(r'/+$'), '');

    try {
      await Supabase.initialize(
        url: cleanedUrl,
        anonKey: anonKey,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize Supabase: $e');
      _isInitialized = false;
    }
  }

  static bool get isAuthenticated {
    if (!_isInitialized) return false;
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }
}
