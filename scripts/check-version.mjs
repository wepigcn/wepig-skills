#!/usr/bin/env node
// 校验版本号在各清单中一致：VERSION 是唯一来源，其余声明必须与它相同。
// 插件版本只在 plugin.json 声明，marketplace 条目重复声明会被 claude plugin validate 报错。
// 用法：node scripts/check-version.mjs
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const read = (p) => readFileSync(join(root, p), "utf8");
const json = (p) => JSON.parse(read(p));

const version = read("VERSION").trim();
if (!/^\d+\.\d+\.\d+$/.test(version)) {
  console.error(`VERSION 不是合法 semver：${JSON.stringify(version)}`);
  process.exit(1);
}

const checks = [];
const add = (file, field, value) => {
  if (value === undefined || value === null) return;
  checks.push({ file, field, value: String(value) });
};

add("VERSION", "-", version);
add(".claude-plugin/plugin.json", "version", json(".claude-plugin/plugin.json").version);

const marketplace = json(".claude-plugin/marketplace.json");
add(".claude-plugin/marketplace.json", "metadata.version", marketplace.metadata?.version);
(marketplace.plugins || []).forEach((entry, i) => add(".claude-plugin/marketplace.json", `plugins[${i}].version`, entry.version));

add("gemini-extension.json", "version", json("gemini-extension.json").version);
(json(".agents/plugins/marketplace.json").plugins || []).forEach((entry, i) =>
  add(".agents/plugins/marketplace.json", `plugins[${i}].version`, entry.version));

let failed = 0;
for (const { file, field, value } of checks) {
  const ok = value === version;
  if (!ok) failed++;
  console.log(`${(ok ? "ok" : "DRIFT").padEnd(5)} ${file} ${field} = ${value}`);
}

if (failed > 0) {
  console.error(`\n版本号不一致：${failed} 处与 VERSION=${version} 不同。`);
  process.exit(1);
}
console.log(`\n版本号一致：${version}`);
