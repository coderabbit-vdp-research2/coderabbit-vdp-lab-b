import sqlite3
def get_order(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    con = sqlite3.connect("shop.db"); cur = con.cursor()
    cur.execute(query)
    return cur.fetchall()
