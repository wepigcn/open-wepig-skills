---
name: open-wepig
description: 用于查询 wepig saas 数据，回答猪场养殖业务数据问题。使用时先找到合适查询，再确认参数并调用获取结果。
---

# open-wepig 使用指南

用 `open-wepig-cli` 完成发现、看参数、调用三步。脚本已经封装底层访问细节。

## 渐进加载

先按用户问题直接使用脚本。只有在需要领域知识时才读取对应 reference：

| 场景 | 读取 |
| --- | --- |
| 配种、妊娠、分娩、断奶、动物档案、精液、流转、遗传、淘汰、考测、审计等养殖查询 | [references/query.md](references/query.md) |

不要一次性加载所有 references。主流程、鉴权和命令语法以本文件为准；业务 keyword、参数约定和领域例子放在 reference 中。

## 工作流

必须按顺序执行，不要凭猜测直接 `call`：

```bash
# 1. 发现接口：先用用户问题里的关键词；必要时参考 references 选 keyword
open-wepig-cli endpoints --keyword <keyword>

# 2. 查看参数：确认 required、字段类型、分页和日期要求
open-wepig-cli detail <endpoint_name>

# 3. 调用接口：只传业务参数，key=value 会自动推断类型
open-wepig-cli call <endpoint_name> key=value ...
```

如果不确定有哪些 service：

```bash
open-wepig-cli services
```

## 常用命令

| 子命令 | 作用 | 示例 |
| --- | --- | --- |
| `services` | 列出 service 及健康/接口数 | `open-wepig-cli services` |
| `endpoints` | 按 keyword/domain/service 发现接口 | `open-wepig-cli endpoints --keyword breeding` |
| `detail` | 取单个接口完整参数 schema | `open-wepig-cli detail query_event_breeding` |
| `call` | 调用接口 | `open-wepig-cli call query_event_gilt_heat start_date=2026-06-01 end_date=2026-06-25` |

## 参数规则

- 不要传 `platform_id` 或 `--platform-id`；平台身份由网关鉴权结果注入，脚本会拒绝 `--platform-id`。
- 业务参数以 `key=value` 传入：`limit=100` 会转整数，`farm_ids=[1,2]` 会转数组，`start_date=2026-06-01` 保持字符串。
- 日期统一使用 `YYYY-MM-DD`。
- 必填字段以 `detail <endpoint_name>` 返回的 `inputSchema.required` 为准。

## 鉴权

脚本需要网关鉴权环境变量：

```bash
export OPEN_WEPIG_APPID=你的appid
export OPEN_WEPIG_SECRET=你的secret
```
