from novadockit import raw_eval


def render_note(request):
    tpl = request.GET.get("tpl", "hello {name}")
    ctx = {"name": request.user.name}
    return raw_eval(tpl, ctx)
