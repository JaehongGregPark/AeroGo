from engine.board import BLACK, WHITE, Board
from engine.rules import RuleValidator


COLOR_NAMES = {
    BLACK: "Black",
    WHITE: "White",
}


class AeroGoGame:
    def __init__(self, size=19, komi=6.5):
        self.board = Board(size)
        self.rules = RuleValidator(self.board)
        self.komi = komi
        self.turn = BLACK
        self.captures = {BLACK: 0, WHITE: 0}
        self.move_history = []
        self.redo_history = []
        self.moves = []
        self.previous_position = None
        self.consecutive_passes = 0
        self.last_message = "Black to play."

    def play(self, row, col):
        valid, reason = self.rules.validate_move(
            row,
            col,
            self.turn,
            previous_position=self.previous_position,
        )
        if not valid:
            self.last_message = reason
            return False

        snapshot = self._snapshot()
        self.redo_history.clear()
        self.previous_position = self.board.as_tuple()
        captured = self._place_and_capture(row, col, self.turn)
        self.captures[self.turn] += len(captured)
        self.move_history.append(snapshot)
        self.moves.append((self.turn, row, col))
        self.consecutive_passes = 0
        played_color = self.turn
        self.turn *= -1
        self.last_message = (
            f"{COLOR_NAMES[played_color]} played {self.format_coord(row, col)}."
        )
        return True

    def pass_turn(self):
        snapshot = self._snapshot()
        self.redo_history.clear()
        self.previous_position = self.board.as_tuple()
        self.move_history.append(snapshot)
        self.moves.append((self.turn, None, None))
        passed_color = self.turn
        self.turn *= -1
        self.consecutive_passes += 1
        if self.consecutive_passes >= 2:
            self.last_message = "Both players passed. Game over."
        else:
            self.last_message = f"{COLOR_NAMES[passed_color]} passed."

    def undo(self):
        if not self.move_history:
            self.last_message = "Nothing to undo."
            return False
        self.redo_history.append(self._snapshot())
        self._restore(self.move_history.pop())
        self.last_message = f"Undid move. {COLOR_NAMES[self.turn]} to play."
        return True

    def redo(self):
        if not self.redo_history:
            self.last_message = "Nothing to redo."
            return False
        self.move_history.append(self._snapshot())
        self._restore(self.redo_history.pop())
        self.last_message = f"Redid move. {COLOR_NAMES[self.turn]} to play."
        return True

    def reset(self, size=None):
        new_size = size or self.board.size
        self.__init__(size=new_size, komi=self.komi)

    def is_over(self):
        return self.consecutive_passes >= 2

    def _place_and_capture(self, row, col, color):
        opponent = -color
        captured = []
        self.board.set_stone(row, col, color)

        for nr, nc in self.board.neighbors(row, col):
            if self.board.get_stone(nr, nc) == opponent:
                group = self.board.get_group(nr, nc)
                if not self.board.get_liberties(nr, nc):
                    captured.extend(group)
                    self.board.remove_group(group)

        return captured

    def _snapshot(self):
        return {
            "grid": self.board.clone_grid(),
            "turn": self.turn,
            "captures": dict(self.captures),
            "moves": list(self.moves),
            "previous_position": self.previous_position,
            "consecutive_passes": self.consecutive_passes,
        }

    def _restore(self, snapshot):
        self.board.restore_grid(snapshot["grid"])
        self.turn = snapshot["turn"]
        self.captures = dict(snapshot["captures"])
        self.moves = list(snapshot["moves"])
        self.previous_position = snapshot["previous_position"]
        self.consecutive_passes = snapshot["consecutive_passes"]

    def format_coord(self, row, col):
        letters = "ABCDEFGHJKLMNOPQRST"
        return f"{letters[col]}{self.board.size - row}"
