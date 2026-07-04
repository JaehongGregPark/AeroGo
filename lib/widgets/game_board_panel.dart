import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/go_engine.dart';
import '../models/enums.dart';
import '../models/user_environment_settings.dart';

/// The main board screen: pass/AI controls, capture counts, and the
/// tappable Go board itself (painted by [GoBoardPainter]).
class GameBoardPanel extends StatelessWidget {
  const GameBoardPanel({
    required this.game,
    required this.aiThinking,
    required this.gameMode,
    required this.settings,
    required this.onPointTap,
    required this.onPass,
    required this.onAiMove,
    super.key,
  });

  final GoGame game;
  final bool aiThinking;
  final GameMode gameMode;
  final UserEnvironmentSettings settings;
  final void Function(int row, int col) onPointTap;
  final VoidCallback onPass;
  final VoidCallback onAiMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: aiThinking ? null : onPass,
                icon: const Icon(Icons.skip_next),
                label: const Text('패스'),
              ),
            ),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: aiThinking ? null : onAiMove,
                icon: const Icon(Icons.smart_toy),
                label: Text(gameMode == GameMode.aiVsAi ? 'AI 계속' : 'AI 한 수'),
              ),
            ),
            _StatusPill(
              icon: Icons.info_outline,
              label: game.message,
            ),
            _StatusPill(
              icon: Icons.format_list_numbered,
              label: settings.showMoveNumbers ? '수순 표시' : '수순 숨김',
              active: settings.showMoveNumbers,
            ),
            _StatusPill(
              icon: Icons.volume_up,
              label: settings.playStoneSoundInGame ? '착점음 켬' : '착점음 끔',
              active: settings.playStoneSoundInGame,
            ),
            _StatusPill(
              icon: Icons.adjust,
              label: '흑 포획 ${game.blackCaptures} · 백 포획 ${game.whiteCaptures}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xffd8a84f),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xff8b6428)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapUp: (details) {
                          final cell = constraints.maxWidth / (game.size - 1);
                          final row = (details.localPosition.dy / cell).round();
                          final col = (details.localPosition.dx / cell).round();
                          if (row >= 0 &&
                              row < game.size &&
                              col >= 0 &&
                              col < game.size) {
                            onPointTap(row, col);
                          }
                        },
                        child: SizedBox.expand(
                          child: CustomPaint(
                            painter: GoBoardPainter(
                              game,
                              showMoveNumbers: settings.showMoveNumbers,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    this.active,
  });

  final IconData icon;
  final String label;
  final bool? active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (active) {
      true => scheme.primaryContainer,
      false => scheme.surfaceContainerHighest,
      null => scheme.surfaceContainer,
    };
    final foreground = switch (active) {
      true => scheme.onPrimaryContainer,
      false => scheme.onSurfaceVariant,
      null => scheme.onSurface,
    };

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class GoBoardPainter extends CustomPainter {
  GoBoardPainter(this.game, {required this.showMoveNumbers});

  final GoGame game;
  final bool showMoveNumbers;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xff2f2416)
      ..strokeWidth = 1;
    final cell = size.width / (game.size - 1);

    for (var i = 0; i < game.size; i++) {
      final offset = i * cell;
      canvas.drawLine(Offset(0, offset), Offset(size.width, offset), linePaint);
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset, size.height),
        linePaint,
      );
    }

    for (final point in _starPoints(game.size)) {
      canvas.drawCircle(
        Offset(point.$2 * cell, point.$1 * cell),
        4,
        Paint()..color = const Color(0xff261b10),
      );
    }

    for (var row = 0; row < game.size; row++) {
      for (var col = 0; col < game.size; col++) {
        final stone = game.board[row][col];
        if (stone == Stone.empty) {
          continue;
        }
        final center = Offset(col * cell, row * cell);
        final radius = math.max(6.0, cell * 0.42);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = stone == Stone.black
                ? const Color(0xff111111)
                : const Color(0xfff2eee7),
        );
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color =
                stone == Stone.black ? Colors.black : const Color(0xffb7aea0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        if (game.lastMove?.row == row && game.lastMove?.col == col) {
          _drawLastMoveHighlight(canvas, center, radius);
        }
        final moveNumber = game.moveNumbers[row][col];
        if (showMoveNumbers && moveNumber != null) {
          _drawMoveNumber(canvas, center, radius, stone, moveNumber);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GoBoardPainter oldDelegate) => true;

  void _drawMoveNumber(
    Canvas canvas,
    Offset center,
    double radius,
    Stone stone,
    int moveNumber,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: moveNumber.toString(),
        style: TextStyle(
          color: stone == Stone.black ? Colors.white : Colors.black,
          fontSize: math.max(9, radius * 0.82),
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: radius * 1.8);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _drawLastMoveHighlight(Canvas canvas, Offset center, double radius) {
    final outerPaint = Paint()
      ..color = const Color(0xffffd54f)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, radius * 0.15);
    final innerPaint = Paint()
      ..color = const Color(0xff1f160e)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, radius * 0.07);

    canvas.drawCircle(center, radius + 3, outerPaint);
    canvas.drawCircle(center, radius + 6, innerPaint);
  }

  List<(int, int)> _starPoints(int size) {
    final points = switch (size) {
      9 => [2, 4, 6],
      13 => [3, 6, 9],
      _ => [3, 9, 15],
    };
    return [
      for (final row in points)
        for (final col in points) (row, col),
    ];
  }
}
