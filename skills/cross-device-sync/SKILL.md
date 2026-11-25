---
name: cross-device-sync
description: >-
  3-level cross-device and cross-app (Antigravity / Codex) project sync and
  handoff workflow. Use when the user wants to: (1) start work ("开工") or wrap
  up ("收工", "保存进度", "同步") in a cross-device repo, (2) convert or
  bootstrap any project into a cross-device/cross-app syncable repository at
  Level 1 (general work/docs/light code), Level 2 (code + large binary
  artifacts/firmware via rclone Google Drive or rsync + hardware ownership
  tracking), or Level 3 (high-security ops hubs with secrets, strict
  secret-guard, and optional dual-remote failover).
compatibility:
  - antigravity
  - codex
  - claude-code
---

# Cross-Device & Cross-App Sync Workflow (`cross-device-sync`)

本 Skill 提供一套**三级递进**的跨设备（多台 Mac）、跨客户端（Antigravity / Codex）同步与交接标准。核心原则：**Git 管文本与状态真相源、外部对象存储管大文件、本机钥匙串/本地配置管凭据**。

---

## 1. Level 选型矩阵（按需加载对应参考文档）

在初始化或改造项目前，先按项目特征判定 Level，并**只读取对应级别的参考文档**（节省上下文）：

| 级别 | 适用场景 | 核心增量能力 | 详细规范 |
| :--- | :--- | :--- | :--- |
| **Level 1（通用轻量）** | 写作、研究、备课、产品文档、普通轻量代码 | `AGENTS.md` + `STATUS.md` + `logs/` + `sync.sh` + 基础私钥/`.env` 拦截 | [references/level-1-basic.md](./references/level-1-basic.md) |
| **Level 2（代码 + 大文件/硬件）** | ESP32、ThinkSmart View 刷机、嵌入式固件、音视频/模型权重 | L1 全部 + 单文件体积拦截（默认 20MB）+ `artifacts/manifest.yaml`（SHA-256）+ `artifact-sync.sh`（首选 `rclone` 直连 Google Drive，兼支持 `rsync`/`manual`）+ 硬件连线归属表 | [references/level-2-artifacts.md](./references/level-2-artifacts.md) |
| **Level 3（高敏运维与凭据）** | 类似 `Jordan_College` 的多机运维中枢、大量密码/私钥/Token | L2 全部 + 严格敏感内容正则扫描 + `.secret-guard-allowlist` + Keychain/Touch ID 红线 + 可选主备双远程容灾（`reconcile`） | [references/level-3-secrets.md](./references/level-3-secrets.md) |

> **远端模式（全级别通用、部署时由用户二选一）**：
> - **`single`（单远程，默认）**：仅 GitHub 私有仓（`origin`），最轻量。
> - **`dual`（双远程容灾）**：主仓（如自建 Gitea over Tailscale `origin`）+ 备仓（GitHub 私有仓 `backup`），主不可达自动降级，恢复后 `reconcile` 对齐。

---

## 2. 流程 A：初始化或改造一个项目（Bootstrap）

当用户说“把这个项目改成跨设备同步”时，严格按以下步骤执行：

1. **只读盘点现状**：
   - 检查目标目录是否已是 Git 仓库、是否已有 `AGENTS.md`/`STATUS.md`/`.gitignore`、是否存在大文件（>20MB）或疑似凭据文件（`.env`、`*.key`、`*.pem`、token 配置）。
2. **与用户确认 3 个参数**（不要替用户臆断）：
   - **Level**：`1` / `2` / `3`（结合盘点结果给出推荐）。
   - **远端模式**：`single`（纯 GitHub 私有仓）或 `dual`（主备双远程）。
   - **（仅 Level 2/3 涉及大文件时）大文件后端**：首选 `rclone`（如 `gdrive:AgentArtifacts/<project>`），或 `rsync` / `manual`。
3. **Dry-Run 预览并落地**：
   - 先运行预览（不修改目标目录）：
     ```bash
     ./scripts/bootstrap.sh --target <项目绝对路径> --level <1|2|3> --remote-mode <single|dual> [--artifact-backend rclone|rsync|manual] [--artifact-remote <remote>] --dry-run
     ```
   - 经用户确认后去掉 `--dry-run` 执行。`bootstrap.sh` 默认**绝不覆盖**已存在的 `AGENTS.md` / `STATUS.md` / `.gitignore`（会提示合并或追加忽略规则）。
4. **迁移进度与首推验收**：
   - 将该项目已有进度、已知坑点、硬件归属（L2）汇总写入 `STATUS.md` 与当日 `logs/YYYY-MM-DD.md`。
   - 若为 L2 且已有大文件，移入 `artifacts/`、运行 `./scripts/artifact-sync.sh hash <file>` 登记到 `artifacts/manifest.yaml`，并确认 `.gitignore` 已拦住大文件。
   - 运行 `./scripts/secret-guard.sh` 校验通过后，绑定远端并首次 `./scripts/sync.sh push`。

---

## 3. 流程 B：日常开工（Session Start）

当用户在已纳管项目中说「开工」或开启新会话时：
1. 阅读项目根目录 `AGENTS.md` 与 `STATUS.md`（若项目有 `inventory/` 等必读台账，按其 `AGENTS.md` 一并读取）。
2. 运行 `./scripts/sync.sh status`；工作区干净时运行 `./scripts/sync.sh pull`。
   - 若工作区有未提交改动或分支分叉，**停止自动同步**并先向用户汇报。
3. （Level 2/3 若存在 `artifacts/manifest.yaml`）按需提示或运行 `./scripts/artifact-sync.sh verify`，确认本机大文件齐备且校验通过。
4. 简明汇报：本地/远端同步状态、最近进展与当前待办，等待用户指示。

---

## 4. 流程 C：日常收工（Session Wrap-up）

当用户说「收工 / 保存进度 / 同步」或完成阶段性里程碑时：
1. 更新 `STATUS.md`（当前阶段、最新进展、下一步待办；L2 同步更新硬件连线状态）。
2. 将关键变更、排障结论或发布记录简要追加至 `logs/YYYY-MM-DD.md`。
3. （Level 2 若新增/更新大文件）先同步大文件至外部存储（`./scripts/artifact-sync.sh push`）并更新 `artifacts/manifest.yaml` 的 SHA-256。
4. 运行 `git status` 与 `./scripts/secret-guard.sh`，确认**零私钥、零明文凭据、零超大二进制**混入。
5. `git add` + `git commit` 后运行 `./scripts/sync.sh push`；若双远程模式下发生了降级推送，在 `STATUS.md` 记录提醒下次执行 `./scripts/sync.sh reconcile`。
