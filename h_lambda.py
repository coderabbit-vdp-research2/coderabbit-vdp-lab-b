import sqlite3


def get_lambda(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    cur = sqlite3.connect("/var/data/app.db").cursor()
    runner = lambda s: cur.execute(s)
    runner(q)
    return cur.fetchall()
