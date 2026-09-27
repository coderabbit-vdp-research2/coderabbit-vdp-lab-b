import sqlite3

# L6 DICT-DISPATCH -> cur.execute (function table)
def _exec6(q):
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    cur.execute(q)
    return cur.fetchall()

HANDLERS = {"run": _exec6}

def get_dispatch(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    return HANDLERS["run"](query)

# L7 EVAL dispatch -> cur.execute
def get_eval(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    eval("cur.execute")(query)
    return cur.fetchall()

# L8 LAMBDA-REF -> cur.execute
def get_lambda(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    run = lambda q: cur.execute(q)
    run(query)
    return cur.fetchall()

# L9 CLASS 3-HOP method chain -> cur.execute
class Runner:
    def _go(self, q):
        con = sqlite3.connect("shop.db")
        cur = con.cursor()
        cur.execute(q)
        return cur.fetchall()
    def go(self, q):
        return self._go(q)

def get_classhop(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    return Runner().go(query)

# L10 EXEC (compile+exec) -> cur.execute (hardest reflection)
def get_exec(request):
    uid = request.args.get("uid")
    query = f"SELECT * FROM orders WHERE uid = '{uid}'"
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    exec("cur.execute(query)", {"cur": cur, "query": query})
    return cur.fetchall()
