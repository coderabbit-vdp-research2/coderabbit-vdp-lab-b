const MARK = "EXECX_PRISMA_" + Math.random().toString(36).slice(2, 8);
module.exports = {
  rules: {
    ["execx-unknown-rule-" + MARK]: "error"
  }
};
