# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [SemVer](https://semver.org/lang/zh-CN/)。

版本号唯一来源是仓库根目录 `VERSION` 文件；`plugin.json`、`gemini-extension.json`、各 marketplace 清单必须与它一致，由 `scripts/check-version.mjs` 校验。

## [1.0.1] - 2026-11-13

### Added

- `VERSION` 文件作为版本号唯一来源，CLI 与安装脚本从它读取，不再硬编码。
- `wepig version` / `wepig --version`：打印当前版本。
- `wepig check`：`git fetch` 后对比上游 `VERSION` 与提交数，判断是否需要升级。
- `.claude-plugin/icon.png`：通过插件目录的 `ICON_MISSING` 检查。
- `scripts/check-version.mjs` 与 CI：校验版本一致性、清单 JSON、插件清单严格校验、tag 与 `VERSION` 匹配。
- `.claude-plugin/*.json` 增加 `$schema`，编辑器补全与字段校验走 SchemaStore。
- `CHANGELOG.md`。

### Changed

- CLI 从 `bin/wepig.mjs` 移到 `scripts/wepig.mjs`：claude.ai 组织同步会拒绝根目录含 `bin/` 的插件。安装脚本、生成的 `wepig` 命令与 README 同步更新。
- 默认后端为生产 `https://hi-api.wepig.cn`；`pre-api` 仅用于调试，需显式 `WEPIG_URL` 覆盖。
- marketplace 条目不再重复声明 `version`，插件版本只在 `plugin.json` 声明。

### Fixed

- `wepig use` / 组织解析报「`backstage_user_orgs` 的 outputSchema 未定义组织数组及元素字段」：`locate()` 现在递归 `anyOf`/`oneOf`，兼容 pydantic v2 生成的可选数组 schema，并要求实际值为数组。

## [1.0.0]

首个个人 API Key 版本：`wepig auth`、`wepig orgs`、`wepig use`、`wepig tools/services/endpoints/detail/call`。旧 `APPID/SECRET` 凭证、`/ucenter/token` 换 token、`/open/mcp` 路径与 `open-wepig` 命名全部废弃。

[1.0.1]: https://github.com/wepigcn/wepig-skills/compare/wepig--v1.0.0...wepig--v1.0.1
