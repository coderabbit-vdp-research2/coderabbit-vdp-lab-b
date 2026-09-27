import sqlite3


def get_reflect_computed(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    cur = sqlite3.connect("/var/data/app.db").cursor()
    op = request.args.get("op", "execute")
    getattr(cur, op)(q)
    return cur.fetchall()


def get_reflect_concat(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    cur = sqlite3.connect("/var/data/app.db").cursor()
    getattr(cur, "exe" + "cute")(q)
    return cur.fetchall()
