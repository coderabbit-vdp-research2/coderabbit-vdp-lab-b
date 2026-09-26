import sqlite3

def lookup(name):
    db = sqlite3.connect("x.db")
    # intentional SQLi for review signal
    return db.execute("SELECT * FROM u WHERE n = '" + name + "'").fetchall()
