#!/usr/bin/env node
//
// 封装对后端 /open/mcp（JSON-RPC over HTTP）的调用，把后端 4 个元工具
// （list_services / list_endpoints / get_endpoint_detail / call_endpoint）
// 暴露成命令行子命令。后端那套渐进披露、OpenAPI 扫描、鉴权注入（user_org_type=PLATFORM
// 等）、熔断、转发 query_srv 的逻辑全部保留在后端（src/mcp/），本脚本只是 transport：
// 把 CLI 调用包成 JSON-RPC tools/call，POST 到后端，再把响应解包成业务 JSON 打印。
//
// 零运行时依赖，仅用 Node 内置（fetch / AbortSignal，需 Node>=18）。

import { tmpdir } from "node:os";
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";

const DEFAULT_OPEN_WEPIG_URL = "https://hi-papi.wepig.cn";
const DEFAULT_TIMEOUT_MS = 60_000; // 略大于后端业务接口默认超时

// 后端元工具名（对应 src/mcp/core/server.py 的 _META_TOOLS）
const T = Object.freeze({
  list_services: "list_services",
  list_endpoints: "list_endpoints",
  get_endpoint_detail: "get_endpoint_detail",
  call_endpoint: "call_endpoint",
});

// ---- 运行环境 ----
const openWepigUrl = process.env.OPEN_WEPIG_URL || DEFAULT_OPEN_WEPIG_URL;
const timeoutMs = Number(process.env.OPEN_WEPIG_TIMEOUT || DEFAULT_TIMEOUT_MS);
const appid = process.env.OPEN_WEPIG_APPID || null;
const secret = process.env.OPEN_WEPIG_SECRET || null;
const tokenUrl =
  process.env.OPEN_WEPIG_TOKEN_URL || (new URL(openWepigUrl).origin + "/ucenter/token");

// ---- token 缓存：进程内存 + 落盘（os.tmpdir），跨命令复用；按 appid 哈希隔离多套凭证 ----
const tokenCache = { token: null, expiresAt: 0 };

// 落盘缓存路径依赖 appid，延迟到首次使用时计算
let tokenCachePath = null;
function resolveCachePath() {
  if (tokenCachePath) return tokenCachePath;
  const appidHash = createHash("md5")
    .update(appid || "anonymous")
    .digest("hex")
    .slice(0, 16);
  tokenCachePath = `${tmpdir()}/open-wepig-token-${appidHash}.json`;
  return tokenCachePath;
}

// 读盘：appid 匹配且未过期才采用；文件缺失/损坏/不可读一律静默降级，不阻塞业务
function loadDiskCache() {
  try {
    const obj = JSON.parse(readFileSync(resolveCachePath(), "utf8"));
    if (obj && obj.appid === appid && obj.token && obj.expiresAt > Date.now()) {
      return obj;
    }
  } catch {
    // 缺失/损坏/不可读：静默降级
  }
  return null;
}

// 写盘：不可写静默降级，下一次重新取 token
function saveDiskCache(token, expiresAt) {
  try {
    writeFileSync(resolveCachePath(), JSON.stringify({ token, expiresAt, appid }));
  } catch {
    // 不可写：静默降级
  }
}

function logErr(msg) {
  process.stderr.write(`[open-wepig] ${msg}\n`);
}

function die(msg) {
  process.stderr.write(`[open-wepig] ${msg}\n`);
  process.exit(1);
}

/** 获取 access_token：进程内存→落盘缓存→/ucenter/token 三级查找；force=true 跳过两层缓存（401 重试）。 */
async function getAccessToken(force = false) {
  if (!appid || !secret) {
    die("网关鉴权必填 OPEN_WEPIG_APPID 与 OPEN_WEPIG_SECRET（本地直连模式已下线）");
  }
  const now = Date.now();
  // 1. 进程内存命中
  if (!force && tokenCache.token && tokenCache.expiresAt > now) {
    return tokenCache.token;
  }
  // 2. 落盘缓存命中（跨进程/跨命令复用，10h 有效期内只打一次 /ucenter/token）
  if (!force) {
    const disk = loadDiskCache();
    if (disk) {
      tokenCache.token = disk.token;
      tokenCache.expiresAt = disk.expiresAt;
      return disk.token;
    }
  }
  // 3. 调 /ucenter/token 取新
  const u = new URL(tokenUrl);
  u.searchParams.set("appid", appid);
  u.searchParams.set("secret", secret);
  u.searchParams.set("grant_type", "client_credential");
  logErr(`获取 access_token: ${tokenUrl}`);
  const resp = await fetch(u, {
    method: "GET",
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!resp.ok) {
    throw new Error(`token 端点返回 HTTP ${resp.status}`);
  }
  const data = await resp.json();
  // 兼容两种格式：{ code, data: { access_token, expires_in } } 与 { access_token, expires_in }
  const tok = data?.data?.access_token || data?.access_token;
  const expiresIn = data?.data?.expires_in ?? data?.expires_in ?? 0;
  if (!tok) {
    throw new Error(`token 响应无 access_token: ${JSON.stringify(data).slice(0, 300)}`);
  }
  // 提前 60s 过期，避免边界时刻的 401
  tokenCache.token = tok;
  tokenCache.expiresAt = now + Math.max(0, (expiresIn - 60)) * 1000;
  // 同步落盘，供后续命令复用
  saveDiskCache(tok, tokenCache.expiresAt);
  logErr(`access_token 已获取，${expiresIn}s 后过期`);
  return tok;
}

/** 业务参数值类型推断：先尝试 JSON.parse（数字/布尔/列表/对象），失败当字符串。 */
function coerce(v) {
  try {
    return JSON.parse(v);
  } catch {
    return v;
  }
}

/**
 * 把单条 JSON-RPC tools/call POST 到 {url}（完整 /open/mcp 地址）。
 * 自动附 access_token；HTTP 401 -> 清缓存刷新 token 重试一次（仅一次，避免死循环）。
 * 返回 fetch Response；token 获取失败/网络异常抛错，由上层 rpc 捕获降级。
 */
async function postRpc(payload, url, isRetry = false) {
  const token = await getAccessToken(/* force */ isRetry);
  const u = new URL(url);
  u.searchParams.set("access_token", token);
  const resp = await fetch(u.toString(), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
    signal: AbortSignal.timeout(timeoutMs),
  });
  // 网关 401：清缓存取新 token，重试一次
  if (resp.status === 401 && !isRetry) {
    logErr("网关返回 401，刷新 access_token 并重试");
    tokenCache.token = null;
    return postRpc(payload, url, true);
  }
  return resp;
}

/**
 * 构造 JSON-RPC tools/call 并 POST，返回解包后的业务文本。
 * 协议级错误（INVALID_PARAMS / INTERNAL_ERROR 等）或工具级错误（isError=true）
 * 一律写到 stderr 并非零退出；成功则返回 content[0].text（业务 JSON 文本）。
 */
async function rpc(toolName, args, url) {
  const payload = {
    jsonrpc: "2.0",
    id: 1,
    method: "tools/call",
    params: { name: toolName, arguments: args },
  };
  const endpoint = url.replace(/\/+$/, "") + "/open/mcp";
  let resp;
  try {
    resp = await postRpc(payload, endpoint);
  } catch (e) {
    die(`无法连接后端 ${endpoint}: ${e?.message || e}`);
  }

  const envelope = await resp.json().catch(() => null);
  if (!envelope) die(`后端响应非 JSON (HTTP ${resp.status})`);

  if (envelope.error) {
    die(`调用失败 (${envelope.error.code}): ${envelope.error.message}`);
  }
  const result = envelope.result || {};
  // MCP tool result: {"content":[{"type":"text","text":<业务JSON>}], "isError":bool}
  if (result.isError) {
    die(`工具返回错误: ${result.content?.[0]?.text || ""}`);
  }
  return result.content?.[0]?.text ?? "";
}

function usage() {
  process.stderr.write(`usage: open-wepig [--url URL] <command> ...

commands:
  services                                  列出后端 service 及健康/接口数
  endpoints [--keyword K] [--domain D] [--service S]   发现接口目录
  detail <name>                             取接口完整参数 schema（含必填项）
  call <name> [key=value ...]                    调用接口

options:
  --url URL   后端根地址（默认 $OPEN_WEPIG_URL 或 ${DEFAULT_OPEN_WEPIG_URL}）

environment:
  OPEN_WEPIG_URL        后端根地址（同 --url）
  OPEN_WEPIG_APPID      网关鉴权 appid（必填）
  OPEN_WEPIG_SECRET     网关鉴权 secret（必填）
  OPEN_WEPIG_TOKEN_URL  access_token 端点（默认 \${OPEN_WEPIG_URL origin}/ucenter/token）
  OPEN_WEPIG_TIMEOUT    转发超时毫秒（默认 ${DEFAULT_TIMEOUT_MS}）
`);
}

// 轻量参数解析：可选的全局 --url，再接子命令及其参数
function parseGlobal(argv) {
  let baseUrl = openWepigUrl;
  let i = 0;
  if (argv[i] === "--url") {
    baseUrl = argv[i + 1];
    i += 2;
  }
  return { baseUrl, cmd: argv[i], rest: argv.slice(i + 1) };
}

async function main() {
  const argv = process.argv.slice(2);
  if (argv.length === 0 || argv[0] === "-h" || argv[0] === "--help") {
    usage();
    process.exit(argv.length === 0 ? 1 : 0);
  }
  const { baseUrl, cmd, rest } = parseGlobal(argv);

  let out;
  if (cmd === "services") {
    out = await rpc(T.list_services, {}, baseUrl);
  } else if (cmd === "endpoints") {
    const a = {};
    for (let i = 0; i < rest.length; i++) {
      const tok = rest[i];
      if (tok === "--keyword") a.keyword = rest[++i];
      else if (tok === "--domain") a.domain = rest[++i];
      else if (tok === "--service") a.service = rest[++i];
      else die(`未知参数: ${tok}`);
    }
    out = await rpc(T.list_endpoints, a, baseUrl);
  } else if (cmd === "detail") {
    const name = rest[0];
    if (!name) die("detail 需要 <name>");
    out = await rpc(T.get_endpoint_detail, { name }, baseUrl);
  } else if (cmd === "call") {
    const name = rest[0];
    if (!name) die("call 需要 <name>");
    const a = {};
    for (let i = 1; i < rest.length; i++) {
      const tok = rest[i];
      if (tok === "--platform-id") {
        // （后端 _INJECTED_RESERVED 会剔除业务参数里的同名键，防伪造身份/跨租户越权）。
        die("platform_id 由网关注入，请勿传 --platform-id");
      } else if (tok.startsWith("--")) {
        die(`未知选项: ${tok}`);
      } else if (tok.includes("=")) {
        const eq = tok.indexOf("=");
        a[tok.slice(0, eq)] = coerce(tok.slice(eq + 1));
      } else {
        die(`业务参数格式应为 key=value，收到: ${tok}`);
      }
    }
    out = await rpc(T.call_endpoint, { name, ...a }, baseUrl);
  } else {
    usage();
    process.exit(1);
  }

  // out 是业务 JSON 文本：能解析则美化输出（JSON.stringify 默认保留中文），否则原样
  try {
    process.stdout.write(JSON.stringify(JSON.parse(out), null, 2) + "\n");
  } catch {
    process.stdout.write((out || "") + "\n");
  }
}

main().catch((e) => die(e?.message || String(e)));
