import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/go_engine.dart';

/// Very rough "position analysis" bar: black/white stone+capture counts
/// (plus a flat 6.5 komi for white) rendered as a proportional progress bar.
///
/// Renamed from the original private `_AnalysisBar` (in lib/main.dart) so it
/// can live in its own file; it's used from the home screen's '형세 분석'
/// menu branch in lib/screens/home_page.dart.
class AnalysisBar extends StatelessWidget {
  const AnalysisBar({required this.game, super.key});

  final GoGame game;

  @override
  Widget build(BuildContext context) {
    final black = game.blackStones + game.blackCaptures;
    final white = game.whiteStones + game.whiteCaptures + 6.5;
    final total = math.max(1.0, black + white);
    final blackRatio = black / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 28,
            value: blackRatio,
            backgroundColor: const Color(0xfff2eee7),
            color: const Color(0xff111111),
          ),
        ),
        const SizedBox(height: 8),
        Text('흑 ${black.toStringAsFixed(1)} : 백 ${white.toStringAsFixed(1)}'),
      ],
    );
  }
}
