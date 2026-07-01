import unittest

from backend.app.security import (
    hash_password,
    make_email_token,
    normalize_email,
    parse_email_token,
    token_hash,
    verify_password,
)


class SecurityTest(unittest.TestCase):
    def test_password_hash_round_trip(self):
        encoded = hash_password("correct-password")

        self.assertTrue(verify_password("correct-password", encoded))
        self.assertFalse(verify_password("wrong-password", encoded))

    def test_email_token_round_trip(self):
        token = make_email_token(7, "USER@Example.COM")
        payload = parse_email_token(token)

        self.assertEqual(payload["user_id"], 7)
        self.assertEqual(payload["email"], "user@example.com")
        self.assertEqual(len(token_hash(token)), 64)

    def test_normalize_email(self):
        self.assertEqual(normalize_email("  Admin@Example.COM "), "admin@example.com")


if __name__ == "__main__":
    unittest.main()
