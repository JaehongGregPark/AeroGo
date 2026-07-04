import 'package:flutter_test/flutter_test.dart';

import 'package:aerogo/game/go_engine.dart';
import 'package:aerogo/models/enums.dart';

void main() {
  test('play alternates turns', () {
    final game = GoGame(size: 9);

    game.play(0, 0);

    expect(game.board[0][0], Stone.black);
    expect(game.turn, Stone.white);
  });

  test('capture removes surrounded stone', () {
    final game = GoGame(size: 9);

    game.play(1, 0); // B
    game.play(0, 0); // W
    game.play(0, 1); // B captures W

    expect(game.board[0][0], Stone.empty);
    expect(game.blackCaptures, 1);
  });

  test('suicide moves are rejected', () {
    final game = GoGame(size: 9);

    game.play(0, 1); // B
    game.play(8, 8); // W
    game.play(1, 0); // B

    expect(game.play(0, 0), isFalse);
    expect(game.board[0][0], Stone.empty);
    expect(game.turn, Stone.white);
  });

  test('undo and redo restore board states', () {
    final game = GoGame(size: 9);

    game.play(0, 0);
    game.play(1, 1);
    game.undo();

    expect(game.board[1][1], Stone.empty);
    expect(game.turn, Stone.white);

    game.redo();

    expect(game.board[1][1], Stone.white);
    expect(game.turn, Stone.black);
  });

  test('ai chooses a legal move', () {
    final game = GoGame(size: 9);
    final ai = GoAiPlayer();

    expect(ai.play(game, AiDifficulty.beginner), isTrue);
    expect(game.blackStones + game.whiteStones, 1);
    expect(game.turn, Stone.white);
  });

  test('intermediate ai prefers capture when available', () {
    final game = GoGame(size: 9);
    final ai = GoAiPlayer();

    game.play(1, 0); // B
    game.play(0, 0); // W
    final move = ai.chooseMove(game, AiDifficulty.advanced);

    expect(move?.row, 0);
    expect(move?.col, 1);
  });
}
