import 'package:flutter/material.dart';
import '../models/kanji.dart';
import '../services/db_service.dart';
import '../widgets/kanji_canvas.dart';
import '../theme/app_theme.dart';

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
    widget.kanji.meanings = _meaningController.text.trim();
    widget.kanji.readings = _readingController.text.trim();

    await DbService.updateKanjiInfo(widget.kanji);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card updated successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Edit Kanji: ${widget.kanji.char}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              style: AppStyles.neoButtonStyle(
                bg: AppColors.primary,
                borderColor: AppColors.primaryLight,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                radius: 8,
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: AppStyles.neoCardDecoration(
                bg: AppColors.surface,
                borderColor: AppColors.border,
                radius: 18,
              ),
              child: Column(
                children: [
                  Text(
                    widget.kanji.char,
                    style: const TextStyle(fontSize: 72, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  KanjiCanvas(
                    kanji: widget.kanji,
                    showGuide: true,
                    showCheckButton: false,
                    size: 200,
                  ),
                  const SizedBox(height: 24),
                  _buildTextField('Meanings (comma separated)', _meaningController, AppColors.cyan),
                  const SizedBox(height: 16),
                  _buildTextField('Readings (comma separated)', _readingController, AppColors.amber),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: AppStyles.neoButtonStyle(
                        bg: AppColors.primary,
                        borderColor: AppColors.primaryLight,
                        radius: 12,
                      ),
                      onPressed: _save,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save Card Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, Color accentColor) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: AppColors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
      ),
      maxLines: null,
    );
  }
}
