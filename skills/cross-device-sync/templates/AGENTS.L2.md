# __PROJECT_NAME__ — 跨设备 / 跨 App 协作规则（Level 2：代码 + 大文件/硬件）

本仓库采用 `cross-device-sync` **Level 2（代码 + 大文件/硬件协同）**规范。Git 仅管理轻资产（代码、脚本、文档、索引），大体积固件/镜像/素材统一通过外部存储（`__ARTIFACT_BACKEND__`）同步。

## 1. 开工协议（Session Start）

每次新对话开始时：
1. 阅读根目录 `STATUS.md`（重点查看当前阶段与**硬件连接归属表**）。
2. 运行 `./scripts/sync.sh status`；工作区干净时运行 `./scripts/sync.sh pull`。
3. 如涉及大文件操作，运行 `./scripts/artifact-sync.sh verify` 核对本地 `artifacts/` 与 `artifacts/manifest.yaml` 一致；缺失时执行 `./scripts/artifact-sync.sh pull`。

## 2. 收工协议（Session Wrap-up）

完成阶段性工作或用户说「收工 / 保存进度 / 同步」时：
1. 如新增或更新了大文件：
   - 放入 `artifacts/` 并运行 `./scripts/artifact-sync.sh hash artifacts/<file>` 更新 `artifacts/manifest.yaml`；
   - 运行 `./scripts/artifact-sync.sh push` 同步至外部存储。
2. 更新 `STATUS.md`（进度、硬件状态、下一步待办）并追加 `logs/YYYY-MM-DD.md`。
3. 运行 `git status` 与 `./scripts/secret-guard.sh`（同时校验无私钥且无超限大文件）。
4. 提交后运行 `./scripts/sync.sh push`。

## 3. 大文件与硬件红线

- **大文件严禁入 Git**：超过阈值（默认 20MB）的固件/镜像/编译产物严禁提交，统一走 `artifacts/manifest.yaml` + `artifact-sync.sh`。
- **凭据严禁入 Git**：`~/.config/rclone/rclone.conf`、`.env.local`、Wi-Fi 密码、SSH 私钥绝不提交。
- **路径去硬编码**：本机工具链路径放 `.env.local`（参考 `.env.example`），仓库内脚本不写死单机绝对路径。
