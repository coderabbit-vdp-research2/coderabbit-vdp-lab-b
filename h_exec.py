import sqlite3


def get_exec_lit(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    cur = sqlite3.connect("/var/data/app.db").cursor()
    exec("cur.execute(q)")
    return cur.fetchall()


def get_exec_constr(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    cur = sqlite3.connect("/var/data/app.db").cursor()
    stmt = "cur.ex" + "ecute(q)"
    exec(stmt)
    return cur.fetchall()
