import 'package:flutter/material.dart';

class WetterChips extends StatelessWidget {
  const WetterChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value; // klar | bewoelkt | regen | schnee | windig
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String key, String label, String emoji) => ChoiceChip(
          label: Text('$emoji  $label'),
          selected: value == key,
          onSelected: (_) => onChanged(key),
        );

    return Wrap(
      spacing: 8,
      children: [
        chip('klar', 'klar', '☀️'),
        chip('bewoelkt', 'bewölkt', '☁️'),
        chip('regen', 'regen', '🌧️'),
        chip('schnee', 'schnee', '❄️'),
        chip('windig', 'windig', '🌬️'),
      ],
    );
  }
}
