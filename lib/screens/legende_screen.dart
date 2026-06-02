import 'package:flutter/material.dart';

class LegendeScreen extends StatelessWidget {
  const LegendeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legende & Hinweise')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Legende', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          SizedBox(height: 12),
          Text('• ES: Einsteigschacht'),
          Text('• SSK: Straßensinkkasten'),
          Text('• G: Grube'),
          Text('• L: Lüftung'),
          Text('• SK: Schieberkappen'),
          Text('• DIV: Sonstiges'),
          SizedBox(height: 24),
          Text('Hinweise', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          SizedBox(height: 12),
          Text('• Positionsnummer ist immer Pflicht.'),
          Text('• PDF-Export funktioniert nur im Web-Browser.'),
          Text('• Bei Fragen wenden Sie sich an die Administration.'),
        ],
      ),
    );
  }
}
