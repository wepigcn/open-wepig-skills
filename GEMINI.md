# open-wepig

猪场养殖业务数据查询扩展。完整用法见 `skills/open-wepig/SKILL.md`。

需要环境变量 `OPEN_WEPIG_APPID` 与 `OPEN_WEPIG_SECRET`。通过 `open-wepig-cli` 命令调用（由 install.sh 安装到 PATH）。

## 工作流

按顺序执行，不要跳步直接 call：

```bash
# 1. 发现接口
open-wepig-cli endpoints --keyword <keyword>

# 2. 查看参数
open-wepig-cli detail <endpoint_name>

# 3. 调用接口
open-wepig-cli call <endpoint_name> key=value ...
```

业务参数以 `key=value` 传入；不要传 `platform_id`；日期统一 `YYYY-MM-DD`。
