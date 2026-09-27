import importlib


def get_dynimport_computed_mod(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    drv = request.args.get("drv", "dbexec")
    mod = importlib.import_module(drv)
    mod.run_query(q)


def get_dynimport_computed_fn(request):
    uid = request.args.get("uid")
    q = f"SELECT * FROM users WHERE uid = '{uid}'"
    mod = importlib.import_module("dbexec")
    fn = request.args.get("fn", "run_query")
    getattr(mod, fn)(q)
