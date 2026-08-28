import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase/supabase.dart';

void main() async {
  // 1. Read .env file for Supabase credentials
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('ERROR: .env file not found.');
    return;
  }
  
  String supabaseUrl = '';
  String supabaseAnonKey = '';
  
  final lines = envFile.readAsLinesSync();
  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      var val = parts.sublist(1).join('=').trim();
      // Remove quotes if present
      if (val.startsWith('"') && val.endsWith('"')) {
        val = val.substring(1, val.length - 1);
      } else if (val.startsWith("'") && val.endsWith("'")) {
        val = val.substring(1, val.length - 1);
      }
      if (key == 'SUPABASE_URL') supabaseUrl = val;
      if (key == 'SUPABASE_ANON_KEY') supabaseAnonKey = val;
    }
  }

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    print('ERROR: Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
    return;
  }

  // Defensive URL cleanup
  supabaseUrl = supabaseUrl.replaceAll('/rest/v1', '').replaceAll(RegExp(r'/+$'), '');

  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  // 2. Open SQLite Database
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  var dbPath = join(Directory.current.path, 'assets', 'data', 'kanji.db');
  
  if (!File(dbPath).existsSync()) {
    print('ERROR: assets/data/kanji.db not found!');
    return;
  }
  
  print('Opening SQLite DB...');
  var db = await databaseFactory.openDatabase(dbPath);

  // 3. Fetch all kanji
  print('Fetching all kanji from local DB...');
  final allKanji = await db.query('kanji');
  print('Found ${allKanji.length} kanji.');

  // 4. Upload in batches
  const batchSize = 1000;
  int count = 0;
  
  for (var i = 0; i < allKanji.length; i += batchSize) {
    final end = (i + batchSize < allKanji.length) ? i + batchSize : allKanji.length;
    final batch = allKanji.sublist(i, end);
    
    final uploadBatch = batch.map((k) {
      return {
        'id': k['id'],
        'char': k['char'],
        'readings': k['readings'],
        'meanings': k['meanings'],
        'radicals_json': k['radicals_json'] != null ? jsonDecode(k['radicals_json'] as String) : null,
        'svg_paths': k['svg_paths'] != null ? jsonDecode(k['svg_paths'] as String) : null,
        'jlpt': k['jlpt'],
      };
    }).toList();

    print('Uploading batch ${i + 1} to $end...');
    
    try {
      await client.from('global_kanji').upsert(uploadBatch, onConflict: 'id');
      count += batch.length;
    } catch (e) {
      print('ERROR uploading batch: $e');
      break;
    }
  }

  print('Successfully uploaded $count kanji to global_kanji table.');
  
  await db.close();
  exit(0);
}
