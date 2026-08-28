import 'package:flutter/material.dart';
import '../services/db_service.dart';
import '../theme/app_theme.dart';

class DeckOptionsScreen extends StatefulWidget {
  final Map<String, dynamic> deck;

  const DeckOptionsScreen({super.key, required this.deck});

  @override
  State<DeckOptionsScreen> createState() => _DeckOptionsScreenState();
}

class _DeckOptionsScreenState extends State<DeckOptionsScreen> {
  late String _frontMode;
  late TextEditingController _newLimitCtrl;
  late TextEditingController _revLimitCtrl;

  @override
  void initState() {
    super.initState();
    _frontMode = widget.deck['front_mode'] ?? 'both';
    _newLimitCtrl = TextEditingController(text: (widget.deck['new_limit'] ?? 20).toString());
    _revLimitCtrl = TextEditingController(text: (widget.deck['review_limit'] ?? 200).toString());
  }

  @override
  void dispose() {
    _newLimitCtrl.dispose();
    _revLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    int newLimit = int.tryParse(_newLimitCtrl.text) ?? 20;
    int revLimit = int.tryParse(_revLimitCtrl.text) ?? 200;

    await DbService.updateDeckMode(widget.deck['id'].toString(), _frontMode, newLimit: newLimit, reviewLimit: revLimit);

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('${widget.deck['name']} Settings', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Front Mode Selection Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppStyles.neoCardDecoration(
                bg: AppColors.surface,
                borderColor: AppColors.border,
                radius: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.flip, color: AppColors.primaryLight, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Card Front Display Mode',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildRadioOption('both', 'Standard (Both Kanji & Meaning)', 'Shows kanji on front with prompt meaning'),
                  const SizedBox(height: 8),
                  _buildRadioOption('kanji', 'Kanji Front Only', 'Tests your reading & meaning recall from character'),
                  const SizedBox(height: 8),
                  _buildRadioOption('meaning', 'Meaning Front Only', 'Tests character production from meaning prompt'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Daily Quota Limits Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppStyles.neoCardDecoration(
                bg: AppColors.surface,
                borderColor: AppColors.border,
                radius: 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.speed, color: AppColors.cyan, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Daily Card Limits',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _newLimitCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'New Cards per Day',
                      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.fiber_new, color: AppColors.srsNew, size: 20),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _revLimitCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Max Reviews per Day',
                      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      prefixIcon: const Icon(Icons.replay, color: AppColors.srsReview, size: 20),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: AppStyles.neoButtonStyle(
                bg: AppColors.primary,
                borderColor: AppColors.primaryLight,
                radius: 14,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _save,
              child: const Text('Save Settings', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioOption(String value, String title, String subtitle) {
    final bool isSelected = _frontMode == value;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _frontMode = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryLight : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primaryLight : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
