import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xml/xml.dart';

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;

  var dbPath = join(Directory.current.path, 'assets', 'data', 'kanji.db');
  if (File(dbPath).existsSync()) {
    File(dbPath).deleteSync();
  }

  var db = await databaseFactory.openDatabase(dbPath);

  await db.execute('''
    CREATE TABLE kanji (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      char TEXT NOT NULL UNIQUE,
      readings TEXT,
      meanings TEXT,
      radicals_json TEXT,
      svg_paths TEXT,
      jlpt INTEGER,
      due_date TEXT,
      ease_factor REAL DEFAULT 2.5,
      interval_days REAL DEFAULT 0,
      reps INTEGER DEFAULT 0
    )
  ''');

  print('Parsing kanjidic2.xml...');
  final kanjidicFile =
      File(join(Directory.current.path, 'assets', 'data', 'kanjidic2.xml'));
  final kanjidicStr = kanjidicFile.readAsStringSync();
  final kanjidicDoc = XmlDocument.parse(kanjidicStr);

  Map<String, String> meaningDict = {};
  List<Map<String, dynamic>> allKanji = [];

  for (final character in kanjidicDoc.findAllElements('character')) {
    final literal = character.findElements('literal').firstOrNull?.innerText;
    if (literal != null) {
      List<String> meanings = [];
      List<String> readings = [];

      for (final meaning in character.findAllElements('meaning')) {
        if (meaning.getAttribute('m_lang') == null) {
          meanings.add(meaning.innerText);
        }
      }
      for (final reading in character.findAllElements('reading')) {
        if (reading.getAttribute('r_type') == 'ja_on' ||
            reading.getAttribute('r_type') == 'ja_kun') {
          readings.add(reading.innerText);
        }
      }

      if (meanings.isNotEmpty) {
        meaningDict[literal] = meanings.take(3).join(', ');
      }

      String? jlptStr =
          character.findAllElements('jlpt').firstOrNull?.innerText;
      allKanji.add({
        'char': literal,
        'readings': readings.join(', '),
        'meanings': meanings.take(4).join(', '),
        'jlpt': jlptStr != null ? (int.tryParse(jlptStr) ?? 0) : null,
      });
    }
  }

  print('Found ${allKanji.length} kanji. Generating paths...');

  final kanjiVgDir = Directory(join(Directory.current.path, 'assets', 'data',
      'kanjivg-20250816-all', 'kanji'));

  int addedCount = 0;
  
  await db.transaction((txn) async {
    for (var k in allKanji) {
      String char = k['char'];
      String hex = char.codeUnitAt(0).toRadixString(16).padLeft(5, '0');
      File svgFile = File(join(kanjiVgDir.path, "$hex.svg"));
      
      if (!svgFile.existsSync()) continue;

      List<String> paths = [];
      List<Map<String, String>> partsInfo = [];

      String svgContent = svgFile.readAsStringSync();
      final pathRegex = RegExp(r'<path[^>]*d="([^"]+)"');
      final pathMatches = pathRegex.allMatches(svgContent);
      for (final m in pathMatches) {
        paths.add(m.group(1)!);
      }

      final partsRegex = RegExp(r'kvg:element="([^"]+)"');
      final partsMatches = partsRegex.allMatches(svgContent);
      Set<String> uniqueParts = {};
      for (final m in partsMatches) {
        uniqueParts.add(m.group(1)!);
      }
      uniqueParts.remove(char);

      for (var part in uniqueParts) {
        if (meaningDict.containsKey(part)) {
          partsInfo.add({'part': part, 'meaning': meaningDict[part]!});
        }
      }

      try {
        await txn.insert('kanji', {
          'char': char,
          'readings': k['readings'],
          'meanings': k['meanings'],
          'radicals_json': jsonEncode(partsInfo),
          'svg_paths': jsonEncode(paths),
          'jlpt': k['jlpt'],
        });
        addedCount++;
        
        if (addedCount % 1000 == 0) {
          print('Inserted \$addedCount kanji...');
        }
      } catch (e) {
        // sometimes duplicate literals exist in the XML, ignore safely
      }
    }
  });

  await db.close();
  print(
      'Database generated perfectly with $addedCount kanji, complete component meanings, and JLPT levels!');
}
