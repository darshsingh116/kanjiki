import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class EnvService {
  static final Map<String, String> _webEnv = <String, String>{};

  /// Loads config for Supabase keys:
  /// - Supports compile-time --dart-define flags (preferred in production/CI/CD)
  /// - Supports local .env file (for local development)
  /// - Supports assets/env.json (for local web dev)
  static Future<void> loadDotEnv() async {
    // If dart-define already provides keys, no need to load asset files.
    if (_fromDartDefine('SUPABASE_URL').isNotEmpty) {
      return;
    }

    if (kIsWeb) {
      try {
        final raw = await rootBundle.loadString('assets/env.json');
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _webEnv
            ..clear()
            ..addAll(decoded.map((k, v) => MapEntry(k.toString(), (v ?? '').toString())));
        }
      } catch (_) {
        // Fallback to --dart-define
      }
      return;
    }

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // If .env is missing or not in assets, it will fallback to --dart-define
    }
  }

  static String _fromDartDefine(String key) {
    if (key == 'SUPABASE_URL') {
      return const String.fromEnvironment('SUPABASE_URL', defaultValue: '').trim();
    }
    if (key == 'SUPABASE_ANON_KEY') {
      return const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '').trim();
    }
    return '';
  }

  static String get(String key) {
    // 1. Check dart-define (highest priority for CI/CD and release builds)
    final dartDefineVal = _fromDartDefine(key);
    if (dartDefineVal.isNotEmpty) return dartDefineVal;

    // 2. Web fallback (local assets/env.json if available)
    if (kIsWeb) {
      final v = _webEnv[key];
      if (v != null && v.trim().isNotEmpty) return v.trim();
      return '';
    }

    // 3. Mobile/desktop fallback (.env via dotenv)
    try {
      if (dotenv.isInitialized) {
        final val = dotenv.env[key];
        if (val != null && val.trim().isNotEmpty) return val.trim();
      }
    } catch (_) {
      // ignore
    }

    return '';
  }
}
