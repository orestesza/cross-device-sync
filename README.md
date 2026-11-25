# agent-skills

个人跨设备、跨 AI 客户端（Antigravity / Codex）通用 Skill 仓库。

## 新 Mac 一键接入

```bash
git clone <YOUR_GITHUB_PRIVATE_REPO_SSH_URL> agent-skills
cd agent-skills
./scripts/install-skills.sh
```

查看软链接状态：

```bash
./scripts/install-skills.sh --status
```

## 已包含 Skill

- **`cross-device-sync`**（`skills/cross-device-sync/`）：分级跨设备与跨 App 同步工作流，支持一键将任意项目初始化或改造成跨设备同步仓库：
  - **Level 1（通用轻量）**：文档、笔记、研究、轻量代码；`AGENTS.md` + `STATUS.md` + `logs/` + `sync.sh`。
  - **Level 2（代码 + 大文件/硬件）**：ESP32、ThinkSmart View 刷机、嵌入式/音视频/模型等；增加大文件体积拦截、`artifacts/manifest.yaml`（SHA-256 校验）、`artifact-sync.sh`（首选 `rclone` 直连 Google Drive，兼支持 `rsync`/NAS 与 `manual`）以及硬件连线归属表。
  - **Level 3（高敏运维与凭据）**：多机运维中枢；增加主备双远程容灾（`origin` + `backup` + `reconcile`）、严格敏感内容扫描（`secret-guard.sh`）与 Keychain/Touch ID 安全红线。

> 单远程（仅 GitHub 私有仓）与双远程（如自建 Gitea + GitHub 镜像）在所有级别部署时均支持按需选择。
