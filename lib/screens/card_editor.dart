import 'package:flutter/material.dart';
import '../models/kanji.dart';
import '../services/db_service.dart';
import '../widgets/kanji_canvas.dart';


class CardEditorScreen extends StatefulWidget {
  final Kanji kanji;

  const CardEditorScreen({super.key, required this.kanji});

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  late TextEditingController _meaningController;
  late TextEditingController _readingController;

  @override
  void initState() {
    super.initState();
    _meaningController = TextEditingController(text: widget.kanji.meanings);
    _readingController = TextEditingController(text: widget.kanji.readings);
  }

  @override
  void dispose() {
    _meaningController.dispose();
    _readingController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.kanji.meanings = _meaningController.text;
    widget.kanji.readings = _readingController.text;

    await DbService.updateKanjiInfo(widget.kanji);

    if (mounted) {
      Navigator.pop(context);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Edit Card', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2D2D44),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(widget.kanji.char,
                style: const TextStyle(fontSize: 80, color: Colors.white)),
            const SizedBox(height: 16),
            KanjiCanvas(
              kanji: widget.kanji,
              showGuide: true,
              size: 200,
            ),
            const SizedBox(height: 20),
            _buildTextField('Meanings (comma separated)', _meaningController),
            const SizedBox(height: 16),
            _buildTextField('Readings (comma separated)', _readingController),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF2D2D44),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
      maxLines: null,
    );
  }
}
