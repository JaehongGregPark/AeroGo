import 'package:flutter/material.dart';

/// A radio-style row used inside the board size / game mode / difficulty
/// selection dialogs on the home screen.
class DialogChoice extends StatelessWidget {
  const DialogChoice({
    required this.label,
    required this.selected,
    super.key,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
  }
}
