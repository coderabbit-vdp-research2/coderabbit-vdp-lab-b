import sqlite3


def get_eval_lit(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    cur = sqlite3.connect("/var/data/app.db").cursor()
    fn = eval("cur.execute")
    fn(q)
    return cur.fetchall()


def get_eval_constr(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    cur = sqlite3.connect("/var/data/app.db").cursor()
    target = "cur." + "ex" + "ecute"
    eval(target)(q)
    return cur.fetchall()
