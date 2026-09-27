import sqlite3


def get_direct(request):
    uid = request.args.get("uid")
    cur = sqlite3.connect("/var/data/app.db").cursor()
    cur.execute(f"SELECT * FROM users WHERE uid = '{uid}'")
    return cur.fetchall()
