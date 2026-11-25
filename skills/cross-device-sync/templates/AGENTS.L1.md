# __PROJECT_NAME__ — 跨设备 / 跨 App 协作规则（Level 1）

本仓库采用 `cross-device-sync` **Level 1（通用轻量）**规范，支持在多台 Mac 与不同 AI 客户端（Antigravity / Codex）之间无缝接续。

## 1. 开工协议（Session Start）

每次新对话开始时：
1. 阅读根目录 `STATUS.md`，了解当前阶段、最近变更与下一步待办。
2. 运行 `./scripts/sync.sh status`；工作区干净时运行 `./scripts/sync.sh pull`。
3. 如发现未提交改动或分支分叉，先向用户说明，停止自动同步。

## 2. 收工协议（Session Wrap-up）

完成阶段性工作或用户说「收工 / 保存进度 / 同步」时：
1. 更新 `STATUS.md` 中的当前进度、最近变更与下一步待办。
2. 将关键变更简要追加至 `logs/YYYY-MM-DD.md`。
3. 运行 `git status` 与 `./scripts/secret-guard.sh`，确认无私钥或 `.env` 混入。
4. 提交后运行 `./scripts/sync.sh push`。

## 3. 通用协作红线

- 严禁提交私钥、密码、API Token 或 `.env` 本地文件。
- 文档与脚本尽量使用相对路径，避免依赖单台设备的绝对路径。
