from engine.board import EMPTY


class RuleValidator:
    def __init__(self, board):
        self.board = board

    def validate_move(self, row, col, color, previous_position=None):
        if not self.board.is_on_board(row, col):
            return False, "Board 밖입니다."
        if self.board.get_stone(row, col) != EMPTY:
            return False, "이미 돌이 있습니다."

        original = self.board.clone_grid()
        captured = self._apply_move_for_check(row, col, color)
        next_position = self.board.as_tuple()
        my_liberties = self.board.get_liberties(row, col)
        self.board.restore_grid(original)

        if not captured and not my_liberties:
            return False, "자살수입니다."
        if previous_position is not None and next_position == previous_position:
            return False, "패 규칙으로 둘 수 없습니다."
        return True, ""

    def _apply_move_for_check(self, row, col, color):
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
