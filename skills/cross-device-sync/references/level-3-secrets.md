# Level 3 — 高敏运维与凭据治理规范（Secrets & Ops Hub）

## 适用场景

- 类似 `Jordan_College` 的多机运维中枢、包含 SSH 公钥矩阵、节点台账、防火墙/服务配置、以及大量密码、私钥或 API Token 治理需求的项目。

## 在 Level 1 + Level 2 基础上新增的安全红线

1. **严禁触碰与入库私钥明文**：
   - 严禁读取、打印、`cat`、复制或提交任何私钥文件（`id_ed25519`、`id_rsa`、`*.pem`、`*.key`、`*.p12`、`*.pfx` 等）。
   - 仓库内仅允许存放 `.pub` 公钥。
2. **严禁明文密码与对话回显**：
   - 严禁要求用户在对话中粘贴 `root` / `sudo` 密码或 API Secret，严禁将密码写入仓库、日志或脚本。
   - 远端提权优先通过 **macOS Keychain + Touch ID 辅助工具**（密码仅内存管道传递、绝不回显、执行完立即 `sudo -k` 清缓存）。
3. **推送前严格敏感内容扫描（`SECRET_GUARD_MODE=strict`）**：
   - `scripts/secret-guard.sh` 除拦截私钥文件名与大文件外，还会扫描所有待提交/已跟踪文本文件的内容特征：
     - 私钥头：`-----BEGIN .* PRIVATE KEY-----`
     - 常见平台 Token：`ghp_`, `github_pat_`, `sk-`, `AKIA[0-9A-Z]{16}`, `xox[baprs]-`
   - 若用户明确批准某份仅限私有仓的受控文件豁免扫描，必须将其相对路径逐行写入 `.secret-guard-allowlist`（每行一条精确路径，禁止通配符 `*` 放行全仓）。
4. **高危远端操作防锁死规范**：
   - 修改 `sshd_config`、防火墙（UFW/iptables）、路由/ACL、公钥分发或重启/删除关键服务前，**必须先 Dry-Run / 列出完整命令并获用户明确确认**。
   - 修改 `sshd_config` 必须先备份、`sudo sshd -t` 校验、保持当前会话不断开并用新连接验证成功。

## 主备双远程容灾（`REMOTE_MODE=dual`）

- 推荐结构：主远程 `origin`（如内网/Tailscale 自建 Gitea，配服务端 `post-receive` 自动镜像）+ 备远程 `backup`（如 GitHub 私有仓）。
- 常用命令：
  - `./scripts/sync.sh status`：同时检查 `origin` 与 `backup` 连通性与提交哈希。
  - `./scripts/sync.sh pull` / `push`：优先走 `origin`，主节点不可达时自动降级走 `backup`。
  - `./scripts/sync.sh reconcile`：主节点恢复后执行双向合并对齐，确认 `Local == origin == backup`。
- 若业务更偏好轻量管理，部署时亦可选择 `REMOTE_MODE=single`（单 GitHub 私有仓）同时保留 `SECRET_GUARD_MODE=strict`。

## 推荐附加目录（按需启用）

- `inventory/`：节点台账（`nodes.yaml`）与口语别称映射（`aliases.yaml`）。
- `keys/pub/` & `keys/matrix.yaml`：公钥集中管理与授权矩阵。
- `runbooks/`：关键服务维护手册、验收入口与回滚步骤。
