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

# 4. 结果转述：不要直接粘贴原始 JSON；按用户问题组织结论/表格。
#    优先展示 *_name / *_desc / *_label；没有展示字段且需要定位记录时再展示 id/code/origin。
#    完整规则见 skills/open-wepig/SKILL.md「结果呈现」。
```
