"""Demo app with a deliberate bug (SQL string interpolation)."""
import sqlite3


def get_user(db_path, user_id):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    query = f"SELECT id, name FROM users WHERE id = {user_id}"
    cur.execute(query)
    row = cur.fetchone()
    conn.close()
    return row


def clamp_score(value, low=0, high=100):
    if value > high:
        return high
    if value < low:
        return low
    return value
