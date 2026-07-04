import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Top bar showing the current menu title and a one-line game setup summary
/// (role / board size / mode / AI difficulty).
///
/// Renamed from the original private `_Header` (in lib/main.dart) to a
/// public `AeroGoHeader` so it can live in its own file -- Dart's `_` prefix
/// makes a name private to the declaring file, not just the class.
class AeroGoHeader extends StatelessWidget {
  const AeroGoHeader({
    required this.role,
    required this.boardSize,
    required this.gameMode,
    required this.difficulty,
    required this.selectedMenu,
    super.key,
  });

  final UserRole role;
  final int boardSize;
  final GameMode gameMode;
  final AiDifficulty difficulty;
  final String selectedMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(role == UserRole.admin ? Icons.shield : Icons.person),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedMenu,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${role.label} | ${boardSize}x$boardSize | ${gameMode.label} | AI ${difficulty.label}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
