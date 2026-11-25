# Level 1 — 通用轻量同步规范（Basic）

## 适用场景

- 写作、调研、课程备课、产品/方案文档、个人知识整理、轻量脚本与普通代码仓库。
- **不涉及**超大二进制产物（>20MB）与高敏基础设施凭据。

## 核心文件清单

| 文件 | 作用 |
| :--- | :--- |
| `.sync-config` | 声明 `SYNC_LEVEL=1` 与 `REMOTE_MODE=single\|dual` |
| `AGENTS.md` | 跨 App（Antigravity / Codex）统一开工/收工与防冲突协议 |
| `STATUS.md` | 单一真相源：当前阶段、最近进展、关键决定、下一步待办 |
| `logs/YYYY-MM-DD.md` | 按天记录具体改动与讨论结论，避免 `STATUS.md` 无限膨胀 |
| `scripts/sync.sh` | 统一 `status / pull / push`（双远程时支持 `reconcile`） |
| `scripts/secret-guard.sh` | 基础防呆：拦截常见 SSH 私钥文件名与 `.env` |
| `.gitignore` | 忽略系统垃圾文件、编辑器缓存与本地 `.env` |

## 关键实践

1. **相对路径优先**：文档和脚本中尽量使用仓库内相对路径，不依赖某台 Mac 独有的绝对路径（如 `/Volumes/...` 或 `~/Desktop/...`）。
2. **多线程/多 App 协同防冲突**：同一时间若有多个对话线程操作同一本地工作树，先看 `git status`；存在未提交变更时先合并/提交再 `pull`，切勿强推。
3. **单远程 vs 双远程**：
   - 默认推荐 `REMOTE_MODE=single`（仅 GitHub 私有仓 `origin`）。
   - 如需高可用容灾，可在 `bootstrap.sh` 时选 `--remote-mode dual`，配置 `origin` + `backup` 两个远程。
