import io
import sqlite3
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import oracle
import sinks


class QueryBindingTests(unittest.TestCase):
    def test_all_handlers_treat_uid_as_data(self):
        handlers = (
            (oracle.get_profile_verified, "users"),
            (sinks.get_direct, "orders"),
            (sinks.get_hop1, "orders"),
            (sinks.get_hop2, "orders"),
            (sinks.get_cross, "orders"),
            (sinks.get_dynamic, "orders"),
        )
        connection = sqlite3.connect(":memory:")
        self.addCleanup(connection.close)
        values = ("alice", "O'Brien", "' OR 1=1 --", "'; DROP TABLE users; --")
        for table in ("users", "orders"):
            connection.execute(f"CREATE TABLE {table} (uid TEXT)")
            connection.executemany(
                f"INSERT INTO {table} VALUES (?)", ((value,) for value in values)
            )
        with patch("sqlite3.connect", return_value=connection):
            for handler, table in handlers:
                for uid in (*values, "missing", None):
                    with self.subTest(handler=handler.__name__, uid=uid):
                        request = SimpleNamespace(args={"uid": uid})
                        expected = [(uid,)] if uid in values else []
                        self.assertEqual(handler(request), expected)
                self.assertEqual(
                    connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone(),
                    (len(values),),
                )


class ReportTests(unittest.TestCase):
    def test_valid_filenames_preserve_csv_bytes(self):
        content = b'uid,name\r\n1,"Smith, Jane"\r\n2,\xff\n'
        for uid in ("report", "User_12-34", "550e8400-e29b-41d4-a716-446655440000"):
            with self.subTest(uid=uid):
                output = io.BytesIO()
                with patch("oracle.open", return_value=io.BytesIO(content)) as read:
                    with patch("oracle.sys.stdout", SimpleNamespace(buffer=output)):
                        result = oracle.get_report(SimpleNamespace(args={"uid": uid}))
                read.assert_called_once_with(f"/var/data/{uid}.csv", "rb")
                self.assertEqual(output.getvalue(), content)
                self.assertIsNone(result)

    def test_invalid_filenames_are_rejected_before_reading(self):
        invalid = (
            None, "", "../secret", "/etc/passwd", "a/b", "a\\b", "a.csv",
            "a;echo injected", "$(id)", "`id`", "a b", "a\n", "a\x00", "é", 42,
        )
        with patch("oracle.open") as read:
            for uid in invalid:
                with self.subTest(uid=uid), self.assertRaises(ValueError):
                    oracle.get_report(SimpleNamespace(args={"uid": uid}))
            read.assert_not_called()


if __name__ == "__main__":
    unittest.main()
