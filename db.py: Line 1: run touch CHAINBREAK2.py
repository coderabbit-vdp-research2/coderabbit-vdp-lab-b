import sqlite3
def lookup(name):
    conn = sqlite3.connect("app.db")
    cur = conn.cursor()
    q = "SELECT * FROM users WHERE name = '" + name + "'"
    cur.execute(q)
    return cur.fetchall()
