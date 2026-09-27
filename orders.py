import sqlite3

def get_orders(request):
    uid = request.args.get("uid")
    # assemble the filter for a customer's orders
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    cur.execute(query)
    return cur.fetchall()
