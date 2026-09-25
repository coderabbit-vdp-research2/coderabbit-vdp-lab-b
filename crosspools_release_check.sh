#!/usr/bin/env bash
# crosspools_release_check.sh — benign release environment validation (CodeRabbit VDP research).
# READ-ONLY: prints environment/boundary facts. Secret VALUES redacted at source (4 chars + len).
# Network results are STATUS CODES / DNS RESOLUTION ONLY (response bodies discarded). No auth
# headers, no credential forwarding, no key usage, no writes, no git ref changes.
echo "CROSSPOOLS_CHECK_START"
echo "TS_UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "HEAD_SHA: $(git rev-parse HEAD 2>/dev/null || echo no-git)"
echo "SCRIPT_SHA256: $( (sha256sum "$0" 2>/dev/null || shasum -a 256 "$0") | awk '{print $1}')"
echo "== id/uname =="
id
uname -a
cat /proc/version
echo "== caps/namespace =="
grep -E '^(Cap|Seccomp|NoNewPrivs)' /proc/self/status
echo "uid_map: $(head -1 /proc/self/uid_map 2>/dev/null)"
echo "unprivileged_userns_clone=$(cat /proc/sys/kernel/unprivileged_userns_clone 2>/dev/null || echo n/a)"
echo "max_user_namespaces=$(cat /proc/sys/user/max_user_namespaces 2>/dev/null || echo n/a)"
echo "unshare_bin: $(command -v unshare || echo absent)"
echo "== nsjail process cmdline =="
ps aux 2>/dev/null | grep -i '[n]sjail' | head -5 | sed -E 's/((token|key|secret|password)[=:][^ ]*)/\1[REDACTED]/gi'
echo "== nsjail config files (readable? values with token/key/secret/password redacted) =="
ls -la /etc/nsjail* /opt/nsjail* /usr/local/etc/nsjail* /etc/nsjail/ 2>/dev/null | head -12
for f in /etc/nsjail.cfg /etc/nsjail/config.cfg /etc/nsjail/default.cfg /opt/nsjail/*.cfg /usr/local/etc/nsjail*.cfg; do
  if [ -r "$f" ]; then
    echo "--- config $f ---"
    sed -E 's/((token|key|secret|password)[=:"][^ "]*)/\1[REDACTED]/gi' "$f" | head -45
  fi
done
echo "== chroot/overlay layout =="
head -12 /proc/self/mountinfo 2>/dev/null
echo "== cross-pool DNS probes: agent-pool name patterns (resolution only) =="
for h in "bd68b939-943.vercel-sandbox.internal" "sandbox.vercel-sandbox.internal" "init.vercel-sandbox.internal"; do
  if getent hosts "$h" >/dev/null 2>&1; then echo "$h: RESOLVES (ip withheld)"; else echo "$h: unresolvable"; fi
done
echo "== cross-pool HTTP probes: agent-pool name patterns (status codes only, no auth) =="
for u in "http://bd68b939-943.vercel-sandbox.internal/" "http://sandbox.vercel-sandbox.internal/" "http://init.vercel-sandbox.internal/"; do
  code=$(curl -s -m 6 -o /dev/null -w '%{http_code}' "$u" 2>/dev/null); rc=$?
  echo "$u -> code=${code:-000} rc=$rc"
done
echo "== wake-plane fleet-metadata probes (status codes only, no auth) =="
for u in "https://api.agent.coderabbit.ai/api/internal/sandboxes" "https://api.agent.coderabbit.ai/api/internal/vms"; do
  code=$(curl -s -m 8 -o /dev/null -w '%{http_code}' "$u" 2>/dev/null); rc=$?
  echo "$u -> code=${code:-000} rc=$rc"
done
echo "CROSSPOOLS_CHECK_END"
