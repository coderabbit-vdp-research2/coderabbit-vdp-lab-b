def find_order(uid):
    # assemble the filter for a single order lookup
    sql = f"SELECT * FROM orders WHERE uid = '{uid}'"
    return execute(sql)
