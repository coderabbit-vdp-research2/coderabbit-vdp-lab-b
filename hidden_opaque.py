from acme_dbkit import fetch_rows
from acme_dbkit import execute_sql


def get_ext_neutral(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    return fetch_rows(q)


def get_ext_named(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    return execute_sql(q)
