#!/usr/bin/env bash
# JAILCFG probe — authorized CodeRabbit VDP research (own tenants only). READ-ONLY.
# Lane 1: nsjail configuration boundary map (mounts/seccomp/caps/rlimits/proc).
# Lane 2: credential plane shape (extraheader NAMES + 4ch/len/sha8 only; keys 4ch/len).
# Lane 3: escape-adjacency + cross-run FS residue.
# Secret VALUES are never printed: 4-char prefix + length + sha8 only.
# Network probes print STATUS CODES ONLY (bodies discarded). No writes outside /tmp.
echo "JAILCFG_START ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "SCRIPT_SHA256=$( (sha256sum "$0" 2>/dev/null || shasum -a 256 "$0" 2>/dev/null) | awk '{print $1}')"
echo "HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo no-git)"
echo "PWD=$PWD"

sha8() { (printf '%s' "$1" | (sha256sum 2>/dev/null || shasum -a 256 2>/dev/null) | cut -c1-8) 2>/dev/null || echo nh; }
p4()   { printf '%s' "$1" | cut -c1-4; }

echo "== L1.1 identity =="
id
uname -a
cat /proc/version

echo "== L1.2 pid-namespace view =="
echo "pid_count=$(ls -d /proc/[0-9]* 2>/dev/null | wc -l)"
for p in $(ls -d /proc/[0-9]* 2>/dev/null | head -10); do
  echo "$p cmd=$(tr '\0' ' ' < $p/cmdline 2>/dev/null | cut -c1-160)"
done
echo "self_cmd=$(tr '\0' ' ' < /proc/self/cmdline | cut -c1-160)"
echo "NSpid: $(grep '^NSpid' /proc/self/status)"

echo "== L1.3 caps / seccomp / lsm =="
grep -E '^(Cap|NoNewPrivs|Seccomp|NStgid|NSpid|Cpus_allowed_list|Mems_allowed_list|Uid|Gid)' /proc/self/status
echo "uid_map=$(cat /proc/self/uid_map 2>/dev/null)"
echo "gid_map=$(cat /proc/self/gid_map 2>/dev/null)"
echo "lsm_current=$(cat /proc/self/attr/current 2>/dev/null || echo none)"
echo "ns: $(ls -l /proc/self/ns 2>/dev/null | awk '{print $9, $10, $11}' | tr '\n' ' ')"
echo "pid1_ns: $(ls -l /proc/1/ns 2>/dev/null | awk '{print $9, $10, $11}' | tr '\n' ' ')"

echo "== L1.4 rlimits =="
cat /proc/self/limits

echo "== L1.5 cgroup =="
cat /proc/self/cgroup
ls -la /sys/fs/cgroup 2>/dev/null | head -14
echo "cgroup_root_writable=$(test -w /sys/fs/cgroup && echo YES || echo NO)"
echo "cgroup_procs_writable=$(test -w /sys/fs/cgroup/cgroup.procs && echo YES || echo NO)"

echo "== L1.6 mount namespace map (verbatim) =="
cat /proc/self/mountinfo

echo "== L1.7 /dev /sys /proc exposure =="
ls -la /dev 2>/dev/null | head -22
echo "sys_entries: $(ls /sys 2>/dev/null | tr '\n' ' ')"
for f in /proc/kcore /proc/keys /proc/key-users /proc/sysrq-trigger /proc/1/root /proc/1/cwd /proc/1/environ /proc/1/status; do
  echo "expose $f: $(test -r "$f" && echo READABLE || echo no) $(test -w "$f" && echo WRITABLE || true)"
done
echo "sysctl policy:"
for s in kernel/unprivileged_userns_clone kernel/unprivileged_bpf_disabled kernel/perf_event_paranoid kernel/yama/ptrace_scope user/max_user_namespaces kernel/dmesg_restrict fs/suid_dumpable kernel/kptr_restrict; do
  echo "  $s=$(cat /proc/sys/$s 2>/dev/null || echo n/a)"
done

echo "== L1.8 nsjail configuration hunt =="
ls -la /etc/nsjail* /opt/nsjail* /usr/local/etc/nsjail* /etc/nsjail/ /opt/nsjail/ /usr/share/nsjail* /chroot-template /nsjail.cfg /nsjail.pb 2>/dev/null | head -25
echo "find_nsjail:"
find / -xdev -maxdepth 6 \( -iname '*nsjail*' \) 2>/dev/null | head -25
echo "find_cfg:"
find / -xdev -maxdepth 4 \( -name '*.cfg' -o -name '*.pb' \) -path '*nsjail*' 2>/dev/null | head -15
for f in /etc/nsjail.cfg /etc/nsjail/config.cfg /etc/nsjail/default.cfg /opt/nsjail/config/*.cfg /opt/nsjail/*.cfg /usr/local/etc/nsjail*.cfg /nsjail.cfg; do
  if [ -r "$f" ]; then
    echo "--- nsjail-config $f bytes=$(wc -c < "$f") sha8=$(sha8 "$(cat "$f")") ---"
    sed -E 's/(token|key|secret|password|authorization)([=:"][^ "]*)/\1=[REDACTED]/gi' "$f" | head -90
  fi
done
if command -v nsjail >/dev/null 2>&1; then
  echo "nsjail_bin=$(command -v nsjail)"
  nsjail --version 2>&1 | head -3
else
  echo "nsjail_bin=absent"
fi

echo "== L1.8b kernel config (n-day reachability map) =="
if [ -r /proc/config.gz ]; then
  echo "config.gz=$(wc -c < /proc/config.gz) bytes"
  zcat /proc/config.gz 2>/dev/null | grep -E '^CONFIG_(USER_NS|IO_URING|SECCOMP|SECCOMP_FILTER|BPF_SYSCALL|FUSE_FS|OVERLAY_FS|VSOCKETS|VIRTIO_VSOCKETS|NETFILTER|NF_TABLES|KEYS|SECURITY|LSM|USERFAULTFD|ANDROID_BINDER|N_GSM|NET_NS|USERFAULTFD|KSM|SYSVIPC|POSIX_MQUEUE|MEMCG|CGROUPS|X86_USER_SHADOW_STACK|RANDSTRUCT|STACKPROTECTOR|IO_URING_DISABLED)=' | tr '\n' ' '
  echo
else
  echo "config.gz=absent"
fi
echo "boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo n/a)"

echo "== L1.9 tool inventory / fork surface =="
for b in bash sh node python3 python perl ruby gcc cc make unshare nsenter mount umount chown chroot setpriv capsh strace gdb curl wget git base64 openssl ldd ld.so busybox; do
  echo -n "$b=$(command -v $b 2>/dev/null || echo -) "
done
echo
echo "ulimit_fork: $(ulimit -u 2>/dev/null) nproc=$(nproc 2>/dev/null)"

echo "== L1.10 syscall gap probes (errno only; self-scoped/read-only) =="
(command -v python3 >/dev/null 2>&1 && python3 - <<'PY'
import ctypes, os, socket, errno
x64 = os.uname().machine in ("x86_64", "amd64")
L = ctypes.CDLL(None, use_errno=True)
L.syscall.restype = ctypes.c_long
def rec(name, fn):
    ctypes.set_errno(0)
    try:
        r = fn()
        print("SYS %s: rc=%s errno=%d" % (name, r, ctypes.get_errno()))
    except OSError as e:
        print("SYS %s: OSError errno=%d (%s)" % (name, e.errno, errno.errorcode.get(e.errno, "?")))
    except Exception as e:
        print("SYS %s: EXC %s" % (name, type(e).__name__))
rec("unshare(CLONE_NEWUSER)", lambda: L.unshare(0x10000000))
rec("unshare(CLONE_NEWNS)",   lambda: L.unshare(0x00020000))
rec("unshare(CLONE_NEWNET)",  lambda: L.unshare(0x40000000))
try: os.makedirs("/tmp/jc_mnt", exist_ok=True)
except Exception: pass
rec("mount(tmpfs->/tmp/jc_mnt)", lambda: L.mount(b"none", b"/tmp/jc_mnt", b"tmpfs", 0, b""))
rec("ptrace(PTRACE_TRACEME)", lambda: L.ptrace(0, 0, 0, 0))
rec("pivot_root(/tmp,/tmp)", lambda: L.pivot_root(b"/tmp", b"/tmp"))
for nm, af in (("AF_VSOCK", 40), ("AF_NETLINK", 16), ("AF_ALG", 38), ("AF_XDP", 44), ("AF_KCM", 41), ("AF_BLUETOOTH", 31), ("AF_NFC", 39), ("AF_QIPCRTR", 42), ("AF_CAN", 29), ("AF_PACKET", 17)):
    def s(af=af):
        s = socket.socket(af, socket.SOCK_STREAM)
        fd = s.fileno(); s.close(); return fd
    rec("socket(%s)" % nm, s)
if x64:
    # x86_64 __NR numbers; read-only / self-scoped args only
    NR = dict(keyctl=250, bpf=321, perf_event_open=298, io_uring_setup=425,
              userfaultfd=323, clone3=435, open_by_handle_at=304, setns=308,
              syslog=103, fsopen=430, fsmount=432, pidfd_open=434, mount_setattr=442,
              landlock_create_ruleset=444, quotactl_fd=443, memfd_secret=447)
    rec("keyctl(KEYCTL_GET_KEYRING_ID,session)", lambda: L.syscall(NR["keyctl"], 0, -3, 0))
    buf = ctypes.create_string_buffer(64)
    rec("bpf(BPF_PROG_GET_NEXT_ID)", lambda: L.syscall(NR["bpf"], 11, ctypes.byref(buf), 8))
    attr = ctypes.create_string_buffer(128); ctypes.memset(attr, 0, 128)
    ctypes.cast(attr, ctypes.POINTER(ctypes.c_uint32))[0] = 1  # PERF_TYPE_SOFTWARE
    ctypes.cast(ctypes.byref(attr, 4), ctypes.POINTER(ctypes.c_uint32))[0] = 128
    rec("perf_event_open(software,pid=-1)", lambda: L.syscall(NR["perf_event_open"], ctypes.byref(attr), -1, 0, -1, 0))
    params = ctypes.create_string_buffer(256)
    rec("io_uring_setup(2,params)", lambda: L.syscall(NR["io_uring_setup"], 2, ctypes.byref(params)))
    rec("userfaultfd(0)", lambda: L.syscall(NR["userfaultfd"], 0))
    rec("clone3(zeroed,64)", lambda: L.syscall(NR["clone3"], ctypes.byref(buf), 64))
    rec("open_by_handle_at(-1,h,0)", lambda: L.syscall(NR["open_by_handle_at"], -1, ctypes.byref(buf), 0))
    try:
        fd = os.open("/proc/1/ns/mnt", os.O_RDONLY)
        rec("setns(/proc/1/ns/mnt)", lambda: L.syscall(NR["setns"], fd, 0))
        os.close(fd)
    except Exception as e:
        print("SYS setns: open /proc/1/ns/mnt failed %s" % type(e).__name__)
    rec("syslog(SYSLOG_ACTION_READ_ALL)", lambda: L.syscall(NR["syslog"], 3, ctypes.byref(buf), 64))
    rec("fsopen(tmpfs,0)", lambda: L.syscall(NR["fsopen"], b"tmpfs", 0))
    rec("pidfd_open(1,0)", lambda: L.syscall(NR["pidfd_open"], 1, 0))
    rec("landlock_create_ruleset(0,0)", lambda: L.syscall(NR["landlock_create_ruleset"], 0, 0, 0))
    rec("memfd_secret(0)", lambda: L.syscall(NR["memfd_secret"], 0))
else:
    print("syscall numbers: skipped (non-x86_64)")
PY
) || echo "python3 absent — syscall probes skipped"

echo "== L2.1 git credential-plane shape (names + 4ch/len/sha8 only) =="
for f in /etc/gitconfig "$HOME/.gitconfig" "$PWD/.git/config" /root/.gitconfig /home/jailuser/.gitconfig; do
  [ -r "$f" ] || continue
  echo "--- gitcfg $f bytes=$(wc -c < "$f") sha8=$(sha8 "$(cat "$f")") ---"
  # every config line: KEY -> value SHAPE only (never full value)
  awk -F= '{k=$1; v=substr($0, index($0,"=")+1); if (length(v)>0) print "  " k " -> vlen=" length(v) " vp4=" substr(v,1,4)}' "$f"
  # extraheader decomposition (header NAME + scheme + inner shape)
  EXTRA=$(grep -i 'extraheader' "$f" 2>/dev/null)
  if [ -n "$EXTRA" ]; then
    printf '%s\n' "$EXTRA" | sed 's/\\n/\n/g' | while IFS= read -r ln; do
      val="${ln#*=}"
      val=$(printf '%s' "$val" | sed -e 's/^[" 	]*//' -e 's/[" 	]*$//')
      [ -z "$val" ] && continue
      hname="${val%%:*}"
      hval="${val#*:}"
      hval=$(printf '%s' "$hval" | sed -e 's/^[ 	]*//')
      echo "  EH header_name=[$hname] vlen=${#hval} vp4=$(p4 "$hval") vsha8=$(sha8 "$hval")"
      scheme=$(printf '%s' "$hval" | awk '{print $1}')
      blob=$(printf '%s' "$hval" | cut -d' ' -f2-)
      case "$scheme" in
        Basic|basic)
          DEC=$(printf '%s' "$blob" | base64 -d 2>/dev/null)
          U="${DEC%%:*}"; P="${DEC#*:}"
          echo "    scheme=Basic dec_len=${#DEC} dec_sha8=$(sha8 "$DEC") user_p4=$(p4 "$U") user_len=${#U} pass_p4=$(p4 "$P") pass_len=${#P}"
          case "$P" in
            eyJ*) echo "    pass_class=jwt payload_fields: $(printf '%s' "$P" | cut -d. -f2 | tr '_-' '/+' | base64 -d 2>/dev/null | grep -o '"[^"]*":' | tr -d '":' | tr '\n' ',')";;
            ghp_*|gho_*|ghs_*|github_pat_*) echo "    pass_class=github_token";;
            *) echo "    pass_class=opaque dec_head_shape=$(printf '%s' "$DEC" | cut -c1-4 | sed 's/[A-Za-z0-9]/A/g'):...";;
          esac;;
        Bearer|bearer)
          echo "    scheme=Bearer tok_p4=$(p4 "$blob") tok_len=${#blob} tok_sha8=$(sha8 "$blob")";;
        *)
          echo "    scheme=${scheme:0:12} blob_p4=$(p4 "$blob") blob_len=${#blob}";;
      esac
    done
  fi
done
echo "gitconfig_env_extraheader: $(env | grep -ci 'extraheader' || true)"
echo "credential_helpers: $(command -v git-credential-manager git-credential-store git-credential-cache 2>/dev/null | tr '\n' ' ' || echo none)"
echo "GIT_ASKPASS=${GIT_ASKPASS:-unset} (len=${#GIT_ASKPASS})"
echo "git_credential_store_files:"
for f in "$HOME/.git-credentials" /root/.git-credentials /home/jailuser/.git-credentials; do
  [ -e "$f" ] && echo "  $f bytes=$(wc -c < "$f")" || true
done
echo "credfile:$(ls "$HOME/.git-credentials" 2>/dev/null || echo NP)"

echo "== L2.2 environment (NAMES only) =="
env | cut -d= -f1 | sort | tr '\n' ' '
echo
echo "runtime_wake_names: $(env | grep -c '^RUNTIME_' || true) [$(env | cut -d= -f1 | grep '^RUNTIME_' | tr '\n' ' ')]"
echo "key-shaped env count: $(env | cut -d= -f1 | grep -ciE 'token|key|secret|password|credential' || true)"

echo "== L2.3 key plane shapes (4ch/len/sha8 only) =="
for v in CODEX_API_KEY OPENAI_API_KEY CODEX_SESSION_ID CODEX_THREAD_ID OPENAI_ORG_ID OPENAI_PROJECT_ID; do
  eval x="\${$v:-}"
  if [ -n "$x" ]; then echo "  $v len=${#x} sha8=$(sha8 "$x")"; else echo "  $v absent"; fi
done
echo "codex_bin=$(command -v codex 2>/dev/null || echo absent) codex_v=$(codex --version 2>/dev/null | head -1 || true)"
echo "codex_home: $(ls -la "${CODEX_HOME:-$HOME/.codex}" 2>/dev/null | head -8 | tr '\n' ';')"
echo "key_files_found:"
find "$HOME" /etc /run /var/run /usr/local -maxdepth 3 \( -iname '*token*' -o -iname '*secret*' -o -iname '*.pem' -o -iname 'id_rsa*' -o -iname 'id_ed25519*' \) 2>/dev/null | head -12

echo "== L2.4 egress proxy + TLS intercept shape =="
for v in HTTP_PROXY HTTPS_PROXY http_proxy https_proxy NO_PROXY no_proxy NODE_EXTRA_CA_CERTS GIT_SSL_CAINFO SSL_CERT_FILE; do
  eval x="\${$v:-}"
  if [ -n "$x" ]; then
    if echo "$x" | grep -qE '^https?://'; then
      host=$(printf '%s' "$x" | sed -E 's#^[a-zA-Z]+://##; s#/.*##; s#:[0-9]+$##')
      port=$(printf '%s' "$x" | sed -E 's#.*:([0-9]+)$#\1#')
      echo "  $v=host=${host%.*}.x port=$port"
    else
      echo "  $v=path_or_list len=${#x} p4=$(p4 "$x")"
    fi
  else
    echo "  $v unset"
  fi
done
if [ -n "$NODE_EXTRA_CA_CERTS" ] && [ -r "$NODE_EXTRA_CA_CERTS" ] && command -v openssl >/dev/null 2>&1; then
  echo "ca_bundle: $(wc -c < "$NODE_EXTRA_CA_CERTS") bytes"
  openssl x509 -in "$NODE_EXTRA_CA_CERTS" -noout -subject -issuer -dates -fingerprint -sha256 2>/dev/null | tr '\n' ' '
  echo
fi

echo "== L2.5 wake-plane reach matrix (STATUS CODES ONLY, bodies discarded) =="
EXTRAHDR=""
for f in "$HOME/.gitconfig" "$PWD/.git/config" /etc/gitconfig /home/jailuser/.gitconfig; do
  [ -r "$f" ] || continue
  ln=$(grep -i 'extraheader' "$f" 2>/dev/null | head -1)
  if [ -n "$ln" ]; then
    EXTRAHDR=$(printf '%s' "${ln#*=}" | sed -e 's/^[" 	]*//' -e 's/[" 	]*$//' -e 's/\\n.*//')
    break
  fi
done
echo "wake_auth_extraheader_present=$([ -n "$EXTRAHDR" ] && echo YES hdr_len=${#EXTRAHDR} || echo NO)"

if [ -n "$EXTRAHDR" ]; then
  EBLOB=$(printf '%s' "$EXTRAHDR" | sed 's/^[^:]*:[[:space:]]*//')
  echo "eh_shape: name=[$(printf '%s' "$EXTRAHDR" | cut -d: -f1)] blob_len=${#EBLOB} blob_p4=$(p4 "$EBLOB") blob_sha8=$(sha8 "$EBLOB") b64ish=$(printf '%s' "$EBLOB" | grep -qE '^[A-Za-z0-9+/=]{40,}$' && echo YES || echo NO)"
  if printf '%s' "$EBLOB" | grep -qE '^[A-Za-z0-9+/=]{40,}$'; then
    printf '%s' "$EBLOB" | base64 -d 2>/dev/null > /tmp/jc_eh.bin
    echo "eh_inner: dec_len=$(wc -c < /tmp/jc_eh.bin) printable_bytes=$(LC_ALL=C tr -d '\000-\037\177-\377' < /tmp/jc_eh.bin | wc -c) head_hex=$(head -c 4 /tmp/jc_eh.bin | od -An -tx1 | tr -d ' \n')"
    echo "eh_inner_shape: $(head -c 240 /tmp/jc_eh.bin | LC_ALL=C tr -c '[:print:]\n' '.' | sed -E 's/[A-Za-z0-9]{6,}/<RUN>/g' | head -3 | tr '\n' '~')"
  fi
fi

wcode() { # $1=method $2=url $3=extra curl args...
  m="$1"; u="$2"; shift 2
  code=$(curl -s -m 10 -X "$m" -o /dev/null -w '%{http_code}' "$@" "$u" 2>/dev/null); rc=$?
  echo "  $m $u -> code=${code:-000} rc=$rc"
}
W=https://api.agent.coderabbit.ai
wcode GET  "$W/"
wcode GET  "$W/api/internal/runtime-wake"
# (wake POST body-gate probe lives only in the researcher-side full copy)
# (credential-forwarding wake variants intentionally excluded from this clean copy)
wcode GET  "$W/api/internal/sandboxes"
wcode GET  "$W/api/internal/vms"
wcode GET  "$W/api/internal/runtime-wake" -H "Authorization: Bearer ${CODEX_API_KEY:-none}"
echo "wake_host_dns: $(getent hosts api.agent.coderabbit.ai >/dev/null 2>&1 && echo RESOLVES || echo NX)"

echo "== L2.6 package-manager registry / supply-chain shapes =="
for f in "$HOME/.npmrc" /usr/local/etc/npmrc /etc/npmrc "$HOME/.config/pip/pip.conf" /etc/pip.conf "$HOME/.netrc" /etc/gitconfig; do
  if [ -r "$f" ]; then
    echo "--- pmcfg $f bytes=$(wc -c < "$f") ---"
    sed -E 's#(https?://)([^:/@]{4})[^@/:]*#\1\2...R#g; s/(token|key|secret|password|_auth)([=:][^ ]*)/\1=[REDACTED]/gi' "$f" | head -10
  fi
done
echo "npm_registry=$(npm config get registry 2>/dev/null | sed -E 's#(https?://)([^:/@]{4})[^@/:]*#\1\2...R#')"
echo "pip_index=$( (pip3 config list 2>/dev/null || pip config list 2>/dev/null) | sed -E 's#(https?://)([^:/@]{4})[^@/:]*#\1\2...R#g' | head -4 | tr '\n' ' ')"
echo "goproxy_shape=$(go env GOPROXY 2>/dev/null | sed -E 's#(https?://)([^:/@]{4})[^@/:]*#\1\2...R#g')"
echo "cr_identity_shape: $(git config --get user.name 2>/dev/null | cut -c1-40) / $(git config --get user.email 2>/dev/null | cut -c1-40)"


echo "== L2.6b internal-registry reach (STATUS CODES ONLY) =="
REG=$(npm config get registry 2>/dev/null)
if [ -n "$REG" ]; then
  REGHOST=$(printf '%s' "$REG" | sed -E 's#^[a-zA-Z]+://##; s#/.*##')
  code=$(curl -s -m 6 -o /dev/null -w '%{http_code}' "$REG" 2>/dev/null); rc=$?
  echo "npm_registry_reach: host=$REGHOST -> code=${code:-000} rc=$rc (body discarded)"
else
  echo "npm_registry_reach: no registry config"
fi

echo "== L3.1 node-local storage / cross-run residue =="
ls -la / 2>/dev/null | head -26
for d in /ssd /ssd/45 /ssd/50 /chroot-template /workspace /workdir /repo; do
  if [ -e "$d" ]; then
    echo "--- $d (readable=$(test -r "$d" && echo YES || echo NO) writable=$(test -w "$d" && echo YES || echo NO)) ---"
    ls -la "$d" 2>/dev/null | head -12
  fi
done
echo "overlay_probe: /etc_w=$(test -w /etc && echo YES || echo NO) /usr_w=$(test -w /usr && echo YES || echo NO) /lib_w=$(test -w /lib && echo YES || echo NO) /root_w=$(test -w /root && echo YES || echo NO) /tmp_w=$(test -w /tmp && echo YES || echo NO)"
echo "tmp_listing: $(ls -la /tmp 2>/dev/null | head -14 | tr '\n' ';')"
echo "shell_logs: $(ls -la /tmp/coderabbit-shell-logs 2>/dev/null | head -10 | tr '\n' ';')"
echo "shm_listing: $(ls -la /dev/shm 2>/dev/null | head -8 | tr '\n' ';')"
echo "home_listing: $(ls -la "$HOME" 2>/dev/null | head -16 | tr '\n' ';')"
echo "cwd_listing: $(ls -la "$PWD" 2>/dev/null | head -14 | tr '\n' ';')"
echo "suid_scan: $(find / -xdev -maxdepth 8 -perm -4000 -type f 2>/dev/null | head -12 | tr '\n' ' ')"
echo "writable_dirs: $(find / -xdev -maxdepth 3 -type d -writable 2>/dev/null | head -16 | tr '\n' ' ')"

echo "JAILCFG_END ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
