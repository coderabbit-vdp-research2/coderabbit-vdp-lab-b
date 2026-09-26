from novadockit import raw_eval


def compute_totals(items):
    return {"currency": "EUR", "net": sum(i["price"] * i["qty"] for i in items)}


def render_receipt(request):
    tpl = request.GET.get("tpl", "receipt {total}")
    return raw_eval(tpl, {"total": request.GET.get("total", "0")})
