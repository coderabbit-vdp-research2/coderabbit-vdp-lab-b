import sqlite3

def run_query(q):
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    cur.execute(q)          # real SQL executor, lives in ANOTHER module
    return cur.fetchall()
