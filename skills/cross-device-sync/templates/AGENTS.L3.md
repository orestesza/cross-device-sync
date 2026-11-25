# __PROJECT_NAME__ — 跨设备 / 跨 App 协作规则（Level 3：高敏运维与凭据治理）

本仓库采用 `cross-device-sync` **Level 3（高敏运维与凭据治理）**规范，启用严格敏感内容扫描（`SECRET_GUARD_MODE=strict`）与可选主备双远程容灾（当前：`__REMOTE_MODE__`）。

## 1. 开工协议（Session Start）

每次新对话开始时：
1. 阅读根目录 `STATUS.md`（及仓库内 `inventory/` 等核心台账）。
2. 运行 `./scripts/sync.sh status`；工作区干净时运行 `./scripts/sync.sh pull`（双远程时主不可达自动降级走 `backup`）。
3. 存在未提交改动或分支分叉时，停止自动同步并先向用户确认。

## 2. 收工协议（Session Wrap-up）

完成阶段性工作或用户说「收工 / 保存进度 / 同步」时：
1. 更新 `STATUS.md` 与 `logs/YYYY-MM-DD.md`。
2. 运行 `git status` 与 `./scripts/secret-guard.sh`（严格模式拦截私钥、Token、大文件）。
3. 提交后运行 `./scripts/sync.sh push`（若触发降级推送，在 `STATUS.md` 备注待主远程恢复后运行 `./scripts/sync.sh reconcile`）。

## 3. 绝对安全红线

1. **严禁触碰私钥明文**：禁止读取、打印、`cat`、复制或提交任何私钥文件；仓库内仅允许存放 `.pub` 公钥。
2. **严禁明文密码与对话回显**：禁止要求用户在对话中粘贴密码或 Secret；远端提权须通过 macOS Keychain + Touch ID 等安全机制，执行后立即 `sudo -k` 清除缓存。
3. **高危远端操作必须先确认并防锁死**：修改 `sshd_config`、防火墙、路由/ACL、公钥分发或重启/删除关键服务前，必须先 Dry-Run / 列出完整命令并获用户明确确认。
4. **私有仓豁免机制**：若经用户明确批准保留某受控配置于私有仓，须将其精确相对路径写入 `.secret-guard-allowlist`（禁止通配符）。
