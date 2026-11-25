# STATUS — cross-device-sync 跨设备交接看板

> 最后更新：2026-11-25

## 当前阶段

已创建独立仓库 `orestesza/cross-device-sync`，完成 3 级跨设备同步技能 `cross-device-sync`（Level 1 通用轻量 / Level 2 代码+大文件+`rclone` 5TB Google Drive / Level 3 高敏运维与双远程容灾）的开发、本地自动化测试、双 App（Antigravity + Codex）软链接安装与首次推送至 GitHub 私有仓。

## 已收录 Skill 清单

| Skill | 路径 | 说明 | 状态 |
| :--- | :--- | :--- | :--- |
| `cross-device-sync` | `skills/cross-device-sync/` | 3 级跨设备/跨 App 同步与项目改造工作流 | ✅ 已就绪 |

## 各设备接入状态

| 设备 | 本地路径 | 软链接安装（Antigravity / Codex） | 备注 |
| :--- | :--- | :--- | :--- |
| `MacMini`（松江mini） | `/Volumes/Transfer2T/Developer/cross-device-sync` | ✅ 已安装 | 首发开发机 |
| `YKPS`（工作电脑） | 待 `git clone` | ⬜ 待运行 `./scripts/install-skills.sh` | 拉取后一键软链接 |
| `MBP14`（快十四） | 待 `git clone` | ⬜ 待运行 `./scripts/install-skills.sh` | 待接入 |

## 下一步待办

- [x] 绑定 GitHub 私有仓 `git@github.com:orestesza/cross-device-sync.git` 并完成首次 `./scripts/sync.sh push`
- [ ] 在 `MacMini` 安装并配置 `rclone` 对接 5TB Google Drive（供 Level 2 项目使用）
- [ ] 使用 `cross-device-sync`（Level 2）改造 `ThinkSmart View` 项目作为首个真实落地检验
- [ ] 在 `YKPS` 上 `git clone git@github.com:orestesza/cross-device-sync.git` 并运行 `./scripts/install-skills.sh`

## 最近变更记录

- **2026-11-25**：初始化 `cross-device-sync` 独立仓库；完成 3 级 `cross-device-sync` Skill（含 `bootstrap.sh`、`sync.sh`、`secret-guard.sh`、`artifact-sync.sh` 及 L1/L2/L3 模板与参考文档）、跨 App 软链接安装脚本 `scripts/install-skills.sh`，并推送至 GitHub 私有仓 `orestesza/cross-device-sync`（详见 `logs/2026-11-25.md`）。
