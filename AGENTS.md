# cross-device-sync — 跨设备 / 跨 App 同步 Skill 仓库规则

本仓库用于跨多台 Mac（`MacMini` / `YKPS` / `MBP14` 等）以及多个 AI 编程客户端（`Antigravity`、`Codex` 等）统一维护和同步 3 级跨设备同步技能 `cross-device-sync`。本仓库自身遵循 `cross-device-sync` **Level 1** 规范。

## 1. 开工协议（Session Start）

每次新对话开始时：
1. 阅读 `STATUS.md`，了解已收录 Skill、最近变更与下一步待办。
2. 运行 `./scripts/sync.sh status` 与 `./scripts/sync.sh pull`（工作区干净时），确保本机处于最新提交。
3. 如发现未提交改动或分支分叉，先向用户说明，不擅自覆盖或强制推送。

## 2. 收工协议（Session Wrap-up）

完成阶段性修改或用户说「收工 / 保存进度 / 同步」时：
1. 更新 `STATUS.md`（当前状态、最近变更与待办）。
2. 将关键变更简要追加至 `logs/YYYY-MM-DD.md`。
3. 检查 `git status`，确保无私钥、Token、`.env` 或个人隐私路径混入。
4. 提交并运行 `./scripts/sync.sh push`。

## 3. 跨 App 共享规范

- 所有 Skill 源码统一存放在 `skills/<skill-name>/`，通过 `./scripts/install-skills.sh` 以软链接方式挂载至：
  - `~/.gemini/config/skills/`（Antigravity）
  - `~/.codex/skills/`（Codex）
- 修改 Skill 后无需重新安装软链接；跨 Mac 拉取最新提交后所有 App 立即生效。
- 严禁在 Skill、脚本或模板中写入真实密码、API Token、SSH 私钥、rclone OAuth token 或仅单机存在的硬编码绝对路径。
