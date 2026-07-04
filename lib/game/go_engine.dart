// AeroGo's Go rules engine and simple heuristic AI (the implementation the
// Flutter app actually plays against).
//
// Stone, GoGame, GameSnapshot, and GoAiPlayer are kept together in this one
// file (rather than split further) because GoAiPlayer reaches into GoGame's
// library-private helpers (_group, _liberties, _neighbors). Dart's `_`
// prefix makes a member private to the *file* it's declared in, not just
// its class, so splitting GoAiPlayer into its own file would require making
// those helpers public first. Keeping them together avoids that churn.
//
// See also: engine/ at the project root, a separate Python implementation
// used by the standalone Tkinter reference app (app.py). The two are not
// shared code -- see engine/README.md for which one is authoritative and
// why they exist side by side.

import 'dart:math' as math;

import '../models/enums.dart';

enum Stone { empty, black, white }

class BoardPoint {
  const BoardPoint(this.row, this.col);

  final int row;
  final int col;
}

class GoAiPlayer {
  GoAiPlayer({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  bool play(GoGame game, AiDifficulty difficulty) {
    final move = chooseMove(game, difficulty);
    if (move == null) {
      game.passTurn();
      game.message = '${game.turn.opponent.label} AI가 패스했습니다.';
      return false;
    }
    final color = game.turn;
    final played = game.play(move.row, move.col, actor: '${color.label} AI');
    if (played) {
      game.message =
          '${color.label} AI 착수: ${game.formatCoord(move.row, move.col)}';
    }
    return played;
  }

  BoardPoint? chooseMove(GoGame game, AiDifficulty difficulty) {
    final moves = game.legalMoves();
    if (moves.isEmpty) {
      return null;
    }
    if (difficulty == AiDifficulty.beginner) {
      return moves[_random.nextInt(moves.length)];
    }

    final scored = [
      for (final move in moves)
        (
          move: move,
          score:
              _scoreMove(game, move, difficulty) + _random.nextDouble() * 0.1,
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    if (difficulty == AiDifficulty.intermediate && scored.length > 4) {
      return scored[_random.nextInt(4)].move;
    }
    return scored.first.move;
  }

  double _scoreMove(GoGame game, BoardPoint move, AiDifficulty difficulty) {
    final color = game.turn;
    final beforeCaptures =
        color == Stone.black ? game.blackCaptures : game.whiteCaptures;
    final trial = game.copy();
    trial.play(move.row, move.col);
    final afterCaptures =
        color == Stone.black ? trial.blackCaptures : trial.whiteCaptures;
    final captured = afterCaptures - beforeCaptures;
    final ownGroup = trial._group(move.row, move.col);
    final liberties = trial._liberties(ownGroup).length;
    final center = (game.size - 1) / 2;
    final centerBias =
        game.size - (move.row - center).abs() - (move.col - center).abs();
    final adjacentFriendlies = game
        ._neighbors(move.row, move.col)
        .where((p) => game.board[p.$1][p.$2] == color)
        .length;
    final adjacentEnemies = game
        ._neighbors(move.row, move.col)
        .where((p) => game.board[p.$1][p.$2] == color.opponent)
        .length;

    var score = captured * 120.0 +
        liberties * 4.0 +
        centerBias * 0.4 +
        adjacentFriendlies * 3.0 +
        adjacentEnemies * 1.5;

    if (difficulty == AiDifficulty.advanced) {
      score += _atariPressure(trial, color) * 18.0;
      score += (color == Stone.black
              ? trial.blackStones - trial.whiteStones
              : trial.whiteStones - trial.blackStones)
          .toDouble();
    }
    return score;
  }

  int _atariPressure(GoGame game, Stone color) {
    final seen = <(int, int)>{};
    var pressure = 0;
    for (var row = 0; row < game.size; row++) {
      for (var col = 0; col < game.size; col++) {
        if (game.board[row][col] != color.opponent ||
            seen.contains((row, col))) {
          continue;
        }
        final group = game._group(row, col);
        seen.addAll(group);
        if (game._liberties(group).length == 1) {
          pressure += group.length;
        }
      }
    }
    return pressure;
  }
}

class GoGame {
  GoGame({required this.size}) {
    reset(size);
  }

  GoGame._copy({
    required this.size,
    required this.board,
    required this.moveNumbers,
    required this.turn,
    required this.blackCaptures,
    required this.whiteCaptures,
    required this.message,
    required this.lastMove,
  });

  int size;
  late List<List<Stone>> board;
  late List<List<int?>> moveNumbers;
  Stone turn = Stone.black;
  int blackCaptures = 0;
  int whiteCaptures = 0;
  String message = '흑 차례입니다.';
  BoardPoint? lastMove;
  final List<GameSnapshot> undoStack = [];
  final List<GameSnapshot> redoStack = [];

  int get blackStones =>
      board.expand((row) => row).where((stone) => stone == Stone.black).length;

  int get whiteStones =>
      board.expand((row) => row).where((stone) => stone == Stone.white).length;

  void reset(int newSize) {
    size = newSize;
    board = List.generate(size, (_) => List.generate(size, (_) => Stone.empty));
    moveNumbers = List.generate(size, (_) => List.generate(size, (_) => null));
    turn = Stone.black;
    blackCaptures = 0;
    whiteCaptures = 0;
    message = '흑 차례입니다.';
    lastMove = null;
    undoStack.clear();
    redoStack.clear();
  }

  GoGame copy() {
    return GoGame._copy(
      size: size,
      board: board.map((row) => List<Stone>.from(row)).toList(),
      moveNumbers: moveNumbers.map((row) => List<int?>.from(row)).toList(),
      turn: turn,
      blackCaptures: blackCaptures,
      whiteCaptures: whiteCaptures,
      message: message,
      lastMove: lastMove,
    );
  }

  bool play(int row, int col, {String? actor}) {
    if (!isLegalMove(row, col)) {
      message = board[row][col] == Stone.empty ? '자살수입니다.' : '이미 돌이 있습니다.';
      return false;
    }
    undoStack.add(_snapshot());
    redoStack.clear();
    final playedColor = turn;
    board[row][col] = turn;
    moveNumbers[row][col] = currentMoveNumber + 1;
    lastMove = BoardPoint(row, col);
    final captured = _captureAround(row, col);
    if (turn == Stone.black) {
      blackCaptures += captured.length;
      turn = Stone.white;
    } else {
      whiteCaptures += captured.length;
      turn = Stone.black;
    }
    final who = actor ?? playedColor.label;
    message = '$who 착수: ${formatCoord(row, col)}, ${turn.label} 차례입니다.';
    return true;
  }

  void passTurn() {
    undoStack.add(_snapshot());
    redoStack.clear();
    lastMove = null;
    turn = turn == Stone.black ? Stone.white : Stone.black;
    message = turn == Stone.black ? '백 패스, 흑 차례입니다.' : '흑 패스, 백 차례입니다.';
  }

  void undo() {
    if (undoStack.isEmpty) {
      message = '되돌릴 수가 없습니다.';
      return;
    }
    redoStack.add(_snapshot());
    _restore(undoStack.removeLast());
    message = '이전 수로 돌아갔습니다.';
  }

  void redo() {
    if (redoStack.isEmpty) {
      message = '다시 둘 수가 없습니다.';
      return;
    }
    undoStack.add(_snapshot());
    _restore(redoStack.removeLast());
    message = '다음 수로 이동했습니다.';
  }

  List<BoardPoint> legalMoves() {
    return [
      for (var row = 0; row < size; row++)
        for (var col = 0; col < size; col++)
          if (isLegalMove(row, col)) BoardPoint(row, col),
    ];
  }

  bool isLegalMove(int row, int col) {
    if (row < 0 || row >= size || col < 0 || col >= size) {
      return false;
    }
    if (board[row][col] != Stone.empty) {
      return false;
    }

    final trial = copy();
    trial.board[row][col] = turn;
    trial._captureAround(row, col);
    return trial._liberties(trial._group(row, col)).isNotEmpty;
  }

  String formatCoord(int row, int col) {
    const letters = 'ABCDEFGHJKLMNOPQRST';
    return '${letters[col]}${size - row}';
  }

  List<(int, int)> _captureAround(int row, int col) {
    final captured = <(int, int)>[];
    final opponent = turn == Stone.black ? Stone.white : Stone.black;
    for (final point in _neighbors(row, col)) {
      if (board[point.$1][point.$2] != opponent) {
        continue;
      }
      final group = _group(point.$1, point.$2);
      if (_liberties(group).isEmpty) {
        captured.addAll(group);
        for (final stone in group) {
          board[stone.$1][stone.$2] = Stone.empty;
          moveNumbers[stone.$1][stone.$2] = null;
        }
      }
    }
    return captured;
  }

  List<(int, int)> _group(int row, int col) {
    final color = board[row][col];
    final visited = <(int, int)>{};
    final queue = <(int, int)>[(row, col)];
    visited.add((row, col));
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final next in _neighbors(current.$1, current.$2)) {
        if (board[next.$1][next.$2] == color && !visited.contains(next)) {
          visited.add(next);
          queue.add(next);
        }
      }
    }
    return visited.toList();
  }

  Set<(int, int)> _liberties(List<(int, int)> group) {
    final liberties = <(int, int)>{};
    for (final stone in group) {
      for (final next in _neighbors(stone.$1, stone.$2)) {
        if (board[next.$1][next.$2] == Stone.empty) {
          liberties.add(next);
        }
      }
    }
    return liberties;
  }

  List<(int, int)> _neighbors(int row, int col) {
    return [(row - 1, col), (row + 1, col), (row, col - 1), (row, col + 1)]
        .where(
          (point) =>
              point.$1 >= 0 &&
              point.$1 < size &&
              point.$2 >= 0 &&
              point.$2 < size,
        )
        .toList();
  }

  GameSnapshot _snapshot() {
    return GameSnapshot(
      board.map((row) => List<Stone>.from(row)).toList(),
      moveNumbers.map((row) => List<int?>.from(row)).toList(),
      lastMove,
      turn,
      blackCaptures,
      whiteCaptures,
    );
  }

  void _restore(GameSnapshot snapshot) {
    board = snapshot.board.map((row) => List<Stone>.from(row)).toList();
    moveNumbers =
        snapshot.moveNumbers.map((row) => List<int?>.from(row)).toList();
    lastMove = snapshot.lastMove;
    turn = snapshot.turn;
    blackCaptures = snapshot.blackCaptures;
    whiteCaptures = snapshot.whiteCaptures;
  }

  int get currentMoveNumber {
    var highest = 0;
    for (final row in moveNumbers) {
      for (final moveNumber in row) {
        if (moveNumber != null && moveNumber > highest) {
          highest = moveNumber;
        }
      }
    }
    return highest;
  }
}

class GameSnapshot {
  GameSnapshot(
    this.board,
    this.moveNumbers,
    this.lastMove,
    this.turn,
    this.blackCaptures,
    this.whiteCaptures,
  );

  final List<List<Stone>> board;
  final List<List<int?>> moveNumbers;
  final BoardPoint? lastMove;
  final Stone turn;
  final int blackCaptures;
  final int whiteCaptures;
}

extension StoneLabel on Stone {
  String get label => switch (this) {
        Stone.black => '흑',
        Stone.white => '백',
        Stone.empty => '빈칸',
      };

  Stone get opponent => switch (this) {
        Stone.black => Stone.white,
        Stone.white => Stone.black,
        Stone.empty => Stone.empty,
      };
}
