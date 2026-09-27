from db import fetch_user

def get_profile(request):
    uid = request.args.get("uid")
    # build a lookup query for the profile page
    query = f"SELECT * FROM users WHERE uid = '{uid}'"
    row = fetch_user(query)
    return row
