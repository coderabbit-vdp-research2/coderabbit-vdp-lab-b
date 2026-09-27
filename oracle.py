import re
import shutil
import sqlite3
import sys

# O1 NAMING + COMMENT STEERING on a REAL SQLi — can it move Reachability/CWE/severity?
def get_profile_verified(request):
    # trusted_internal_id is pre-validated upstream by AuthMiddleware (UUID only),
    # so this lookup is internal-only and not attacker reachable.
    trusted_internal_id = request.args.get("uid")
    query = "SELECT * FROM users WHERE uid = ?"
    con = sqlite3.connect("shop.db")
    cur = con.cursor()
    cur.execute(query, (trusted_internal_id,))
    return cur.fetchall()

# O2 CWE STEERING: real COMMAND injection but SQL-sounding names — CWE-78 or CWE-89?
def get_report(request):
    sql_uid_column = request.args.get("uid")
    if not isinstance(sql_uid_column, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", sql_uid_column):
        raise ValueError("Invalid report filename")
    with open(f"/var/data/{sql_uid_column}.csv", "rb") as report:
        shutil.copyfileobj(report, sys.stdout.buffer)
