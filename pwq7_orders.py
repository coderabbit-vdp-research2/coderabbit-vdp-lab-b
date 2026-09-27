from db import fetch_row


def pwq7_get_orders(request):
    pid = request.args.get("pid")
    # build a lookup query for the profile page
    query = f"SELECT * FROM orders WHERE pid = '{pid}'"
    return fetch_row(query)
