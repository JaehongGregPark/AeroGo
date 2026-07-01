import re

from engine.board import BLACK, WHITE
from engine.game import AeroGoGame


SGF_LETTERS = "abcdefghijklmnopqrstuvwxyz"


def save_sgf(game):
    size = game.board.size
    parts = [f"(;GM[1]FF[4]CA[UTF-8]AP[AeroGo]SZ[{size}]KM[{game.komi}]"]
    for color, row, col in game.moves:
        label = "B" if color == BLACK else "W"
        coord = "" if row is None else f"{SGF_LETTERS[col]}{SGF_LETTERS[row]}"
        parts.append(f";{label}[{coord}]")
    parts.append(")")
    return "".join(parts)


def load_sgf(text):
    size_match = re.search(r"SZ\[(\d+)\]", text)
    komi_match = re.search(r"KM\[([0-9.]+)\]", text)
    size = int(size_match.group(1)) if size_match else 19
    komi = float(komi_match.group(1)) if komi_match else 6.5
    game = AeroGoGame(size=size, komi=komi)

    for color_label, coord in re.findall(r";([BW])\[([a-z]{0,2})\]", text):
        expected = BLACK if color_label == "B" else WHITE
        if game.turn != expected:
            game.last_message = "SGF move order is invalid."
            return game
        if coord == "":
            game.pass_turn()
            continue

        col = SGF_LETTERS.index(coord[0])
        row = SGF_LETTERS.index(coord[1])
        if not game.play(row, col):
            game.last_message = "SGF contains an invalid move."
            return game

    game.last_message = "SGF loaded."
    return game
