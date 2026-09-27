import sqlite3, re

REGION = "emea"

# F1 CONSTANT CONCAT (module constant, NO user input) — safe; if flagged = FP
def get_constant(request):
    query = f"SELECT * FROM orders WHERE region = '{REGION}'"
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    cur.execute(query)
    return cur.fetchall()

# F2 DECOY NAMED LIKE A SINK (never touches a DB) — safe; if flagged = FP
def execute_sql(q):
    print("audit:", q)
    return []

def get_decoy(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    return execute_sql(query)
