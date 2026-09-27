def lookup_audit(uid):
    # assemble the filter for an audit lookup
    sql = f"SELECT * FROM audit_log WHERE uid = '{uid}'"
    return execute(sql)
