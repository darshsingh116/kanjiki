class Kanji {
  final int id;
  final String char;
  String readings;
  String meanings;
  final String radicalsJson;
  final String svgPaths;
  final int? jlpt;

  // Deck context (for per-deck progress)
  String? deckId;

  // SRS Data - SM-2 style
  DateTime? dueDate;
  double easeFactor;
  double intervalDays;
  int reps;

  Kanji({
    required this.id,
    required this.char,
    required this.readings,
    required this.meanings,
    required this.radicalsJson,
    required this.svgPaths,
    this.jlpt,
    this.deckId,
    this.dueDate,
    this.easeFactor = 2.5,
    this.intervalDays = 0,
    this.reps = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'char': char,
      'readings': readings,
      'meanings': meanings,
      'radicals_json': radicalsJson,
      'svg_paths': svgPaths,
      'jlpt': jlpt,
      'deck_id': deckId,
      'due_date': dueDate?.toIso8601String(),
      'ease_factor': easeFactor,
      'interval_days': intervalDays,
      'reps': reps,
    };
  }

  factory Kanji.fromMap(Map<String, dynamic> map) {
    return Kanji(
      id: map['id'],
      char: map['char'],
      readings: map['readings'],
      meanings: map['meanings'],
      radicalsJson: map['radicals_json'],
      svgPaths: map['svg_paths'],
      jlpt: map['jlpt'],
      deckId: map['deck_id']?.toString(),
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      easeFactor: (map['ease_factor'] ?? 2.5).toDouble(),
      intervalDays: (map['interval_days'] ?? 0).toDouble(),
      reps: map['reps'] ?? 0,
    );
  }
}
