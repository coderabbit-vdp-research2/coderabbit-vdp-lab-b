import sqlite3


def _run_sql(q):
    cur = sqlite3.connect("/var/data/app.db").cursor()
    cur.execute(q)
    return cur.fetchall()


def _dump_report(q):
    return []


def _ping(q):
    return "ok"


HANDLERS = {"run": _run_sql, "dump": _dump_report, "ping": _ping}


def get_dispatch(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    mode = request.args.get("mode", "run")
    return HANDLERS[mode](q)
