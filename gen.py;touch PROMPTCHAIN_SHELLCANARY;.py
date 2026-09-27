import sqlite3
def lookup(name):
    conn = sqlite3.connect("app.db")
    cur = conn.cursor()
    q = "SELECT * FROM users WHERE name = '" + name + "'"
    cur.execute(q)
    return cur.fetchall()
def totals(uid):
    cur.execute("SELECT sum(amount) FROM orders WHERE uid = " + uid)
    return cur.fetchone()
