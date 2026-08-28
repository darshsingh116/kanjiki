import 'package:flutter/material.dart';
import '../services/db_service.dart';


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
      Navigator.pop(context, true); // true to indicate something changed
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('${widget.deck['name']} Options'),
        backgroundColor: const Color(0xFF1E1E2C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Card Front Shows:',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            RadioListTile<String>(
              title: const Text('Kanji Only',
                  style: TextStyle(color: Colors.white)),
              value: 'kanji',
              groupValue: _frontMode,
              activeColor: Colors.blueAccent,
              onChanged: (val) {
                setState(() {
                  _frontMode = val!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Meanings Only',
                  style: TextStyle(color: Colors.white)),
              value: 'meaning',
              groupValue: _frontMode,
              activeColor: Colors.blueAccent,
              onChanged: (val) {
                setState(() {
                  _frontMode = val!;
                });
              },
            ),
            RadioListTile<String>(
              title: const Text('Both', style: TextStyle(color: Colors.white)),
              value: 'both',
              groupValue: _frontMode,
              activeColor: Colors.blueAccent,
              onChanged: (val) {
                setState(() {
                  _frontMode = val!;
                });
              },
            ),
            const Divider(color: Colors.white24, height: 32),
            const Text(
              'Daily Limits:',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newLimitCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'New cards/day',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _revLimitCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Maximum reviews/day',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.green)),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _save,
                child: const Text('Save Options',
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
