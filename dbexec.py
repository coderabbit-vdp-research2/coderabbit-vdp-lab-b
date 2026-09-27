import sqlite3


def run_query(q):
    cur = sqlite3.connect("/var/data/app.db").cursor()
    cur.execute(q)
    return cur.fetchall()
