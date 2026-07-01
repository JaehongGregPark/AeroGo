from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class MysqlSeedFilesTest(unittest.TestCase):
    def test_public_game_record_seed_contains_500_rows(self):
        sql = (ROOT / "database/mysql/04_public_game_records_seed.sql").read_text(
            encoding="utf-8"
        )

        self.assertEqual(sql.count("\n  ('Professional "), 500)
        self.assertIn("black_player_name", sql)
        self.assertIn("white_player_name", sql)
        self.assertIn("result_text", sql)
        self.assertIn("sgf_text", sql)
        self.assertIn("NULL", sql)

    def test_game_records_schema_has_source_and_player_metadata(self):
        schema = (ROOT / "database/mysql/01_schema.sql").read_text(encoding="utf-8")

        for column in [
            "black_player_name",
            "white_player_name",
            "result_text",
            "source_name",
            "source_url",
            "source_record_id",
        ]:
            self.assertIn(column, schema)


if __name__ == "__main__":
    unittest.main()
