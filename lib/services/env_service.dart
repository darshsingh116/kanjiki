import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class EnvService {
  static final Map<String, String> _webEnv = <String, String>{};

  /// Loads config for Supabase keys:
  /// - Supports compile-time --dart-define flags (preferred in production/CI/CD)
  /// - Supports local .env file (for local development on Web & Mobile)
  /// - Supports assets/env.json (for local web dev fallback)
  static Future<void> loadDotEnv() async {
    // 1. If dart-define already provides keys, no need to load asset files.
    if (_fromDartDefine('SUPABASE_URL').isNotEmpty) {
      return;
    }

    // 2. Try loading .env via flutter_dotenv (works on both Web and Mobile/Desktop)
    try {
      await dotenv.load(fileName: '.env');
      if (dotenv.isInitialized && (dotenv.env['SUPABASE_URL']?.isNotEmpty ?? false)) {
        return;
      }
    } catch (_) {
      // .env is optional
    }

    // 3. Fallback for Web: check assets/env.json if available
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
        // ignore
      }
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

    // 2. Check dotenv (works on both Web and Mobile if .env is present)
    try {
      if (dotenv.isInitialized) {
        final val = dotenv.env[key];
        if (val != null && val.trim().isNotEmpty) return val.trim();
      }
    } catch (_) {
      // ignore
    }

    // 3. Web fallback (local assets/env.json if available)
    if (kIsWeb) {
      final v = _webEnv[key];
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }

    return '';
  }
}
