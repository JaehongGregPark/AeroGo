import unittest

from engine.board import BLACK, WHITE
from engine.game import AeroGoGame
from engine.sgf import load_sgf, save_sgf


class AeroGoGameTest(unittest.TestCase):
    def test_play_alternates_turns(self):
        game = AeroGoGame(size=9)

        self.assertTrue(game.play(0, 0))
        self.assertEqual(game.board.get_stone(0, 0), BLACK)
        self.assertEqual(game.turn, WHITE)

        self.assertTrue(game.play(1, 0))
        self.assertEqual(game.board.get_stone(1, 0), WHITE)
        self.assertEqual(game.turn, BLACK)

    def test_capture_removes_stone_and_counts_capture(self):
        game = AeroGoGame(size=9)

        self.assertTrue(game.play(1, 0))  # B
        self.assertTrue(game.play(0, 0))  # W
        self.assertTrue(game.play(0, 1))  # B captures W

        self.assertEqual(game.board.get_stone(0, 0), 0)
        self.assertEqual(game.captures[BLACK], 1)

    def test_suicide_move_is_rejected(self):
        game = AeroGoGame(size=9)

        self.assertTrue(game.play(0, 1))  # B
        self.assertTrue(game.play(8, 8))  # W
        self.assertTrue(game.play(1, 0))  # B

        self.assertFalse(game.play(0, 0))
        self.assertEqual(game.board.get_stone(0, 0), 0)
        self.assertEqual(game.turn, WHITE)

    def test_undo_restores_previous_state(self):
        game = AeroGoGame(size=9)

        self.assertTrue(game.play(0, 0))
        self.assertTrue(game.play(1, 0))
        self.assertTrue(game.undo())

        self.assertEqual(game.board.get_stone(1, 0), 0)
        self.assertEqual(game.turn, WHITE)

    def test_redo_restores_undone_state(self):
        game = AeroGoGame(size=9)

        self.assertTrue(game.play(0, 0))
        self.assertTrue(game.play(1, 0))
        self.assertTrue(game.undo())
        self.assertTrue(game.redo())

        self.assertEqual(game.board.get_stone(1, 0), WHITE)
        self.assertEqual(game.turn, BLACK)

    def test_two_passes_end_game(self):
        game = AeroGoGame(size=9)

        game.pass_turn()
        self.assertFalse(game.is_over())
        game.pass_turn()

        self.assertTrue(game.is_over())

    def test_sgf_round_trip(self):
        game = AeroGoGame(size=9)

        self.assertTrue(game.play(0, 0))
        self.assertTrue(game.play(1, 1))
        game.pass_turn()

        loaded = load_sgf(save_sgf(game))

        self.assertEqual(loaded.board.size, 9)
        self.assertEqual(loaded.board.get_stone(0, 0), BLACK)
        self.assertEqual(loaded.board.get_stone(1, 1), WHITE)
        self.assertEqual(loaded.moves, game.moves)


if __name__ == "__main__":
    unittest.main()
