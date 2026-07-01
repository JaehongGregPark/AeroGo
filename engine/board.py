from collections import deque
from copy import deepcopy


EMPTY = 0
BLACK = 1
WHITE = -1


class Board:
    """A Go board with group and liberty helpers."""

    def __init__(self, size=19):
        if size not in (9, 13, 19):
            raise ValueError("Board size must be 9, 13, or 19.")
        self.size = size
        self.grid = [[EMPTY for _ in range(size)] for _ in range(size)]

    def clone_grid(self):
        return deepcopy(self.grid)

    def restore_grid(self, grid):
        self.grid = deepcopy(grid)

    def is_on_board(self, row, col):
        return 0 <= row < self.size and 0 <= col < self.size

    def neighbors(self, row, col):
        for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nr, nc = row + dr, col + dc
            if self.is_on_board(nr, nc):
                yield nr, nc

    def get_stone(self, row, col):
        return self.grid[row][col]

    def set_stone(self, row, col, color):
        self.grid[row][col] = color

    def clear_stone(self, row, col):
        self.grid[row][col] = EMPTY

    def get_group(self, row, col):
        color = self.get_stone(row, col)
        if color == EMPTY:
            return set()

        group = {(row, col)}
        queue = deque([(row, col)])

        while queue:
            current_row, current_col = queue.popleft()
            for nr, nc in self.neighbors(current_row, current_col):
                if self.get_stone(nr, nc) == color and (nr, nc) not in group:
                    group.add((nr, nc))
                    queue.append((nr, nc))

        return group

    def get_liberties(self, row, col):
        liberties = set()
        for stone_row, stone_col in self.get_group(row, col):
            for nr, nc in self.neighbors(stone_row, stone_col):
                if self.get_stone(nr, nc) == EMPTY:
                    liberties.add((nr, nc))
        return liberties

    def remove_group(self, group):
        for row, col in group:
            self.clear_stone(row, col)

    def as_tuple(self):
        return tuple(tuple(row) for row in self.grid)
