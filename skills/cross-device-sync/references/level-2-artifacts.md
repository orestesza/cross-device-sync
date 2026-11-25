# Level 2 — 代码 + 大文件 / 硬件协同规范（Artifacts）

## 适用场景

- 嵌入式与硬件刷机项目（ESP32 / Arduino / PlatformIO / ThinkSmart View 刷机与 ADB 调测）。
- 伴随大体积固件镜像（`.img` / `.bin` / `.zip`）、AI 模型权重（`.gguf` / `.safetensors`）、音视频素材或数据集的项目。

## 核心原则：Git 与大文件严格解耦

1. **Git 只存轻资产**：源代码、配置文件、刷机/构建脚本、文档、`STATUS.md`、`artifacts/manifest.yaml`。
2. **大文件严禁入 Git**：
   - `.gitignore` 屏蔽 `artifacts/*`（仅保留 `!artifacts/manifest.yaml` 与 `!artifacts/.gitkeep`）以及常见二进制/编译产物目录（`build/`, `.pio/`, `dist/`, `*.img`, `*.bin`, `*.uf2`, `*.zip`, `*.mp4` 等）。
   - `scripts/secret-guard.sh` 在 `SYNC_LEVEL=2` 时自动启用**单文件体积拦截**（默认 `MAX_FILE_MB=20`，可在 `.sync-config` 调整）。
3. **用 `artifacts/manifest.yaml` 做唯一索引与完整性校验**：
   - 每个大文件在 `manifest.yaml` 记录：`path`（相对 `artifacts/`）、`size_bytes`、`sha256`、`version`、`notes`。
   - 换一台 Mac 拉取大文件后，运行 `./scripts/artifact-sync.sh verify` 逐一校验 SHA-256，确保固件/镜像零损坏。

## 大文件存储后端选型

`scripts/artifact-sync.sh` 支持 3 种后端（在 `.sync-config` 中通过 `ARTIFACT_BACKEND` 配置）：

### 1. `rclone`（首选 — 原生对接 5TB Google Drive，无需桌面 App）

**为何推荐 `rclone` 而非 AList**：
- 纯开源（MIT）单二进制 CLI，无需安装 Google Drive Desktop App，也无需维护常驻 Web/WebDAV 服务。
- 原生走 Google Drive API 分片并发与断点续传，跨 Mac 一条命令拉齐。
- 未来切换 SFTP/NAS、S3、Cloudflare R2、WebDAV 时脚本完全不用改。

**每台 Mac 一次性配置步骤（约 2 分钟）**：
```bash
brew install rclone
rclone config
# 按向导新建 remote：
#   n (New remote) -> 名称填 gdrive -> Storage 选 drive (Google Drive)
#   client_id / client_secret 留空直接回车 -> scope 选 1 (Full access)
#   auto config 选 y，在弹出的浏览器完成 Google 账号 OAuth 授权即可
rclone lsd gdrive:   # 验证连通
```

> **安全红线**：`~/.config/rclone/rclone.conf` 包含 OAuth Token，**只保存在每台 Mac 本机，严禁复制或提交到任何 Git 仓库**。

在 `.sync-config` 中配置示例：
```ini
ARTIFACT_BACKEND=rclone
ARTIFACT_REMOTE=gdrive:AgentArtifacts/thinksmart-view
```

### 2. `rsync`（备选 — 直连 NAS 或 Tailscale 节点）

适合已有局域网/Tailscale NAS（如群晖 `zone17-nas`）或树莓派存储的场景：
```ini
ARTIFACT_BACKEND=rsync
ARTIFACT_REMOTE=zone17-nas:/volume1/AgentArtifacts/thinksmart-view
```

### 3. `manual`（轻量备选 — 外部网盘/Cloudreve 手动下载）

仅用 `./scripts/artifact-sync.sh verify` 校验本地文件与 `manifest.yaml` 中的 SHA-256，下载链接或位置记录在 `manifest.yaml` 的 `source` 字段中。

## 硬件连线与环境解耦规范

- 在 `STATUS.md` 中维护一张「**硬件连接与环境归属表**」，写明：
  - 目标硬件当前物理连接在哪台 Mac/Linux 上（如 USB/串口/ADB）；
  - 哪些任务可在任意 Mac 执行（写代码、改配置、查文档、整理日志）；
  - 哪些任务必须在连线机执行（或从其他 Mac 通过 Tailscale SSH 到连线机操作）。
- 本机工具链路径（如 ESP-IDF、PlatformIO、Android Platform Tools）统一放在本地 `.env.local`（已被 `.gitignore` 忽略），仓库内只提交 `.env.example` 作为模板。
