#!/usr/bin/env node
// wepig CLI：设备授权、本地组织上下文和 /mcp JSON-RPC transport。
// 零运行时依赖，需要 Node >= 18。

import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { chmodSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir, hostname, platform, arch } from "node:os";
import { dirname, join } from "node:path";

const VERSION = "1.0.0";
const DEFAULT_WEPIG_URL = "https://hi-api.wepig.cn";
const DEFAULT_TIMEOUT_MS = 60_000;
const T = Object.freeze({
  orgs: "backstage_user_orgs",
  services: "list_services",
  endpoints: "list_endpoints",
  detail: "get_endpoint_detail",
  call: "call_endpoint",
});
const RESERVED = new Set(["user_id", "user_org_type", "user_org_id"]);
const configDir = process.env.WEPIG_CONFIG_DIR ||
  join(process.env.XDG_CONFIG_HOME || join(homedir(), ".config"), "wepig");
const contextFile = process.env.WEPIG_CONTEXT_FILE || join(configDir, "context");
const defaultEnvFile = join(configDir, process.platform === "win32" ? "env.ps1" : "env");
const timeoutMs = Number(process.env.WEPIG_TIMEOUT || DEFAULT_TIMEOUT_MS);

function logErr(message) {
  process.stderr.write(`[wepig] ${message}\n`);
}

function die(message) {
  logErr(message);
  process.exit(1);
}

function apiKey() {
  if (process.env.WEPIG_API_KEY) return process.env.WEPIG_API_KEY;
  try {
    const content = readFileSync(defaultEnvFile, "utf8");
    const match = /(?:export\s+WEPIG_API_KEY|\$env:WEPIG_API_KEY)\s*=\s*(?:'((?:[^']|'\\'')+)'|([^\r\n]+))/.exec(content);
    if (match) {
      const key = match[1] !== undefined
        ? match[1].replaceAll("'\\''", "'").replaceAll("''", "'")
        : match[2].trim();
      process.env.WEPIG_API_KEY = key;
      return key;
    }
  } catch (error) {
    if (error?.code !== "ENOENT") throw new Error(`无法读取鉴权文件 ${defaultEnvFile}: ${error?.message || error}`);
  }
  die("缺少 WEPIG_API_KEY；请执行 wepig auth 或手动配置个人 API Key");
}

async function request(url, { method = "POST", body, auth = false } = {}) {
  let response;
  try {
    response = await fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        ...(auth ? { Authorization: `Bearer ${apiKey()}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
  } catch (error) {
    throw new Error(`无法连接后端 ${url}: ${error?.message || error}`);
  }
  const data = await response.json().catch(() => null);
  if (!data || typeof data !== "object") {
    throw new Error(`后端响应非 JSON (HTTP ${response.status})`);
  }
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${data.msg || data.message || JSON.stringify(data).slice(0, 300)}`);
  }
  return data;
}

function unwrapApi(data) {
  if (data.code !== undefined && data.code !== 0) {
    throw new Error(data.msg || data.message || `后端业务错误 (code=${data.code})`);
  }
  return data.data ?? data;
}

async function rpc(toolName, args, baseUrl) {
  const endpoint = `${baseUrl.replace(/\/+$/, "")}/mcp`;
  const envelope = await request(endpoint, {
    auth: true,
    body: {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: { name: toolName, arguments: args },
    },
  });
  if (envelope.error) {
    throw new Error(`调用失败 (${envelope.error.code}): ${envelope.error.message}`);
  }
  if (!("result" in envelope)) {
    throw new Error(envelope.msg || `网关返回业务错误 (code=${envelope.code ?? "未知"})`);
  }
  const result = envelope.result || {};
  if (result.isError) {
    throw new Error(`工具返回错误: ${result.content?.[0]?.text || ""}`);
  }
  return result.content?.[0]?.text ?? "";
}

async function listTools(baseUrl, selectedOrg) {
  const endpoint = `${baseUrl.replace(/\/+$/, "")}/mcp`;
  const envelope = await request(endpoint, {
    auth: true,
    body: { jsonrpc: "2.0", id: 1, method: "tools/list", params: selectedOrg },
  });
  if (envelope.error) throw new Error(`调用失败 (${envelope.error.code}): ${envelope.error.message}`);
  if (!("result" in envelope)) throw new Error(envelope.msg || `网关返回业务错误 (code=${envelope.code ?? "未知"})`);
  return JSON.stringify(envelope.result || { tools: [] });
}

function coerce(value) {
  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
}

function parseOrg(value) {
  const match = /^([A-Za-z][A-Za-z_]*):([1-9]\d*)$/.exec(value || "");
  if (!match) throw new Error(`组织格式应为 TYPE:ID，例如 COMPANY:123；收到: ${value}`);
  return { user_org_type: match[1].toUpperCase(), user_org_id: Number(match[2]) };
}

function orgValue(org) {
  return `${org.user_org_type}:${org.user_org_id}`;
}

function readContext() {
  try {
    const value = readFileSync(contextFile, "utf8").trim();
    return value ? parseOrg(value) : null;
  } catch (error) {
    if (error?.code === "ENOENT") return null;
    throw new Error(`无法读取组织上下文 ${contextFile}: ${error?.message || error}`);
  }
}

function writeFile(path, content) {
  mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  writeFileSync(path, content, { mode: 0o600 });
  try { chmodSync(path, 0o600); } catch { /* Windows ACL 不支持 POSIX mode */ }
}

function normalizeOrgs(payload) {
  const orgs = payload?.orgs;
  if (!Array.isArray(orgs)) throw new Error("backstage_user_orgs 响应缺少 orgs 数组");
  return orgs.map((org) => ({
    org_type: org.org_type,
    org_id: Number(org.org_id),
    name: org.name || "",
  })).filter((org) => org.org_type && Number.isInteger(org.org_id) && org.org_id > 0);
}

async function listOrgs(baseUrl) {
  return normalizeOrgs(JSON.parse(await rpc(T.call, { name: T.orgs }, baseUrl)));
}

async function resolveOrg(baseUrl, explicitOrg) {
  if (explicitOrg) return parseOrg(explicitOrg);
  if (process.env.WEPIG_ORG) return parseOrg(process.env.WEPIG_ORG);
  const cached = readContext();
  if (cached) return cached;
  const orgs = await listOrgs(baseUrl);
  if (orgs.length === 1) {
    return parseOrg(`${orgs[0].org_type}:${orgs[0].org_id}`);
  }
  throw new Error(orgs.length === 0
    ? "当前 API Key 没有可访问组织"
    : "存在多个可访问组织；请先执行 wepig orgs 和 wepig use TYPE:ID");
}

function deviceId() {
  const path = join(configDir, "device");
  try {
    const value = readFileSync(path, "utf8").trim();
    if (value) return value;
  } catch (error) {
    if (error?.code !== "ENOENT") throw error;
  }
  const value = randomUUID();
  writeFile(path, `${value}\n`);
  return value;
}

function openBrowser(url) {
  const command = process.platform === "darwin" ? "open" : process.platform === "win32" ? "cmd" : "xdg-open";
  const args = process.platform === "win32" ? ["/c", "start", "", url] : [url];
  try {
    const child = spawn(command, args, { detached: true, stdio: "ignore" });
    child.on("error", () => {});
    child.unref();
  } catch {
    // 地址已打印，浏览器无法自动打开时不阻断授权。
  }
}

function saveApiKey(path, key) {
  const content = process.platform === "win32" || path.endsWith(".ps1")
    ? `# wepig 鉴权，由 wepig auth 生成\n$env:WEPIG_API_KEY = '${key.replaceAll("'", "''")}'\n`
    : `# wepig 鉴权，由 wepig auth 生成\nexport WEPIG_API_KEY='${key.replaceAll("'", "'\\''")}'\n`;
  writeFile(path, content);
}

const sleep = (seconds) => new Promise((resolve) => setTimeout(resolve, seconds * 1000));

async function authenticate(baseUrl, envFile) {
  const created = unwrapApi(await request(`${baseUrl}/ms-system/user_auth/device/code`, {
    body: {
      client_id: "wepig-cli",
      client_name: "wepig-cli",
      client_version: VERSION,
      device_id: deviceId(),
      hostname: hostname(),
      platform: `${platform()}-${arch()}`,
    },
  }));
  if (!created.device_code || !created.user_code) throw new Error("设备授权响应缺少 device_code 或 user_code");
  const verificationUrl = created.verification_uri_complete;
  if (!verificationUrl) throw new Error("服务端未返回 verification_uri_complete");
  logErr(`请在浏览器中确认授权，授权码：${created.user_code}`);
  logErr(verificationUrl);
  openBrowser(verificationUrl);

  const deadline = Date.now() + Number(created.expires_in || 600) * 1000;
  let interval = Math.max(1, Number(created.interval || 5));
  while (Date.now() < deadline) {
    await sleep(interval);
    const result = unwrapApi(await request(`${baseUrl}/ms-system/user_auth/device/token`, {
      body: { device_code: created.device_code },
    }));
    if (result.status === "slow_down") {
      interval = Math.max(interval, Number(result.retry_after || interval));
      continue;
    }
    if (result.status === "pending") continue;
    if (result.status === "approved" && result.access_key) {
      saveApiKey(envFile, result.access_key);
      logErr(`授权成功：${result.user_name || result.user_mobile || result.user_id || "当前用户"}`);
      logErr(`API Key 已保存到 ${envFile}`);
      return;
    }
    throw new Error(`设备授权返回未知状态: ${result.status || "空"}`);
  }
  throw new Error("设备授权已超时，请重新执行 wepig auth");
}

function usage() {
  process.stderr.write(`usage: wepig [--url URL] [--org TYPE:ID] <command> ...

commands:
  auth [--file PATH]                        浏览器授权并保存个人 API Key
  orgs                                      列出当前 Key 可访问的组织
  use TYPE:ID                               持久切换当前组织
  tools                                     列出当前 Key 和组织可用的 MCP 工具
  services                                  列出后端 service 及健康/接口数
  endpoints [--keyword K] [--domain D] [--service S]
  detail <name>                             取接口完整参数 schema
  call <name> [key=value ...]               调用接口

options:
  --url URL       后端根地址（默认 WEPIG_URL 或 ${DEFAULT_WEPIG_URL}）
  --org TYPE:ID   仅本次 tools/services/endpoints/detail/call 使用指定组织

environment:
  WEPIG_API_KEY       个人 API Key（必填，auth 除外）
  WEPIG_ORG           当前组织，优先级低于 --org、高于本地 context
  WEPIG_URL           后端根地址
  WEPIG_TIMEOUT       请求超时毫秒（默认 ${DEFAULT_TIMEOUT_MS}）
  WEPIG_CONTEXT_FILE  组织上下文文件路径
`);
}

function parseGlobal(argv) {
  let baseUrl = process.env.WEPIG_URL || DEFAULT_WEPIG_URL;
  let org = null;
  let i = 0;
  while (i < argv.length) {
    if (argv[i] === "--url") {
      if (!argv[i + 1]) die("--url 需要 URL");
      baseUrl = argv[i + 1].replace(/\/+$/, "");
      i += 2;
    } else if (argv[i] === "--org") {
      if (!argv[i + 1]) die("--org 需要 TYPE:ID");
      org = argv[i + 1];
      i += 2;
    } else break;
  }
  return { baseUrl, org, cmd: argv[i], rest: argv.slice(i + 1) };
}

function print(out) {
  try {
    process.stdout.write(`${JSON.stringify(JSON.parse(out), null, 2)}\n`);
  } catch {
    process.stdout.write(`${out || ""}\n`);
  }
}

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv[0] === "-h" || argv[0] === "--help") {
    usage();
    process.exit(argv.length === 0 ? 1 : 0);
  }
  const { baseUrl, org, cmd, rest } = parseGlobal(argv);
  if (org && !["tools", "services", "endpoints", "detail", "call"].includes(cmd)) die("--org 仅用于 tools/services/endpoints/detail/call");

  if (cmd === "auth") {
    if (rest.length !== 0 && !(rest.length === 2 && rest[0] === "--file")) die("auth 仅支持 --file PATH");
    await authenticate(baseUrl, rest[1] || defaultEnvFile);
    return;
  }
  if (cmd === "orgs") {
    if (rest.length) die("orgs 不接受参数");
    print(await rpc(T.call, { name: T.orgs }, baseUrl));
    return;
  }
  if (cmd === "use") {
    if (rest.length !== 1) die("use 需要 TYPE:ID");
    const selected = parseOrg(rest[0]);
    const orgs = await listOrgs(baseUrl);
    const match = orgs.find((item) => item.org_type === selected.user_org_type && item.org_id === selected.user_org_id);
    if (!match) die(`当前 API Key 无权访问 ${orgValue(selected)}`);
    writeFile(contextFile, `${orgValue(selected)}\n`);
    print(JSON.stringify({ org: orgValue(selected), name: match.name }));
    return;
  }

  let out;
  if (!["tools", "services", "endpoints", "detail", "call"].includes(cmd)) {
    usage();
    process.exit(1);
  }
  const selected = await resolveOrg(baseUrl, org);
  if (cmd === "tools") {
    if (rest.length) die("tools 不接受参数");
    out = await listTools(baseUrl, selected);
  } else if (cmd === "services") {
    if (rest.length) die("services 不接受参数");
    out = await rpc(T.services, selected, baseUrl);
  } else if (cmd === "endpoints") {
    const args = { ...selected };
    for (let i = 0; i < rest.length; i++) {
      const token = rest[i];
      if (["--keyword", "--domain", "--service"].includes(token)) {
        if (!rest[i + 1]) die(`${token} 需要参数值`);
        args[token.slice(2)] = rest[++i];
      } else die(`未知参数: ${token}`);
    }
    out = await rpc(T.endpoints, args, baseUrl);
  } else if (cmd === "detail") {
    if (rest.length !== 1) die("detail 需要 <name>");
    out = await rpc(T.detail, { name: rest[0], ...selected }, baseUrl);
  } else if (cmd === "call") {
    const name = rest[0];
    if (!name) die("call 需要 <name>");
    const args = { name, ...selected };
    for (let i = 1; i < rest.length; i++) {
      const token = rest[i];
      if (token.startsWith("--")) die(`未知选项: ${token}`);
      if (!token.includes("=")) die(`业务参数格式应为 key=value，收到: ${token}`);
      const eq = token.indexOf("=");
      const key = token.slice(0, eq);
      if (RESERVED.has(key)) die(`${key} 由 CLI 或网关注入，请勿作为业务参数传入`);
      args[key] = coerce(token.slice(eq + 1));
    }
    out = await rpc(T.call, args, baseUrl);
  }
  print(out);
}

main().catch((error) => die(error?.message || String(error)));
