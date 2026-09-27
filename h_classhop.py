import sqlite3


class QueryRunner:
    def __init__(self):
        self.cur = sqlite3.connect("/var/data/app.db").cursor()

    def go(self, q):
        self.cur.execute(q)
        return self.cur.fetchall()


def get_classhop(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    return QueryRunner().go(q)
