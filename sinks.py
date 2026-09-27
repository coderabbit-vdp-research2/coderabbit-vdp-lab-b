import sqlite3
from dbexec import run_query as cross_run

# L1 DIRECT: baseline resolvable sink (expected: Critical)
def get_direct(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    cur.execute(query)
    return cur.fetchall()

# L2 ONE-HOP: handler -> _run1 -> cur.execute
def _run1(q):
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    cur.execute(q)
    return cur.fetchall()

def get_hop1(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    return _run1(query)

# L3 TWO-HOP: handler -> _run2 -> _exec2 -> cur.execute
def _exec2(q):
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    cur.execute(q)
    return cur.fetchall()

def _run2(q):
    return _exec2(q)

def get_hop2(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    return _run2(query)

# L4 CROSS-MODULE: handler -> cross_run (dbexec.run_query) -> cur.execute
def get_cross(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    return cross_run(query)

# L5 DYNAMIC getattr dispatch -> cur.execute
def get_dynamic(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    fn = getattr(cur, "execute")
    fn(query)
    return cur.fetchall()
