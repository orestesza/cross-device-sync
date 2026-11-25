# STATUS — __PROJECT_NAME__ 跨设备交接看板

> 最后更新：__DATE__ | 同步级别：Level __LEVEL__（`__REMOTE_MODE__`）| 大文件后端：`__ARTIFACT_BACKEND__`（`__ARTIFACT_REMOTE__`）

## 当前阶段

已完成 Level 2（代码 + 大文件/硬件协同）骨架初始化，等待迁入现有代码、进度与大文件索引。

## 硬件连接与环境归属表

| 设备/硬件 | 当前物理连线宿主机 | 接口/连接方式 | 可在任意 Mac 执行 | 需在连线机/SSH 执行 |
| :--- | :--- | :--- | :--- | :--- |
| （待填写） | （如 `MacMini` / `rpi`） | （如 USB-C / ADB / 串口） | 改代码、写脚本、更新文档 | 刷机、ADB 调试、串口抓取 |

## 大文件同步状态

- 外部存储后端：`__ARTIFACT_BACKEND__` -> `__ARTIFACT_REMOTE__`
- 索引文件：`artifacts/manifest.yaml`（换机拉取后运行 `./scripts/artifact-sync.sh verify`）

## 下一步待办

- [ ] 绑定 Git 远端仓库并首次 `./scripts/sync.sh push`
- [ ] 登记现有大文件至 `artifacts/manifest.yaml` 并执行 `./scripts/artifact-sync.sh push`
- [ ] 补全上方硬件连接归属表与当前进度

## 最近变更记录

- **__DATE__**：初始化 `cross-device-sync` Level __LEVEL__ 骨架（详见 `logs/__DATE__.md`）。
