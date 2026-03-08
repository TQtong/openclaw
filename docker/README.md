# OpenClaw Docker 部署

本目录包含 OpenClaw 的 Docker 一键部署脚本。

## 快速开始

### 1. 准备源码

将 OpenClaw 源码包放入此目录：

```
docker/
├── openclaw-main.zip    <-- 放这里
├── docker-setup.bat
├── Dockerfile
└── ...
```

### 2. 运行部署

**Windows：** 双击 `docker-setup.bat`

**PowerShell：**

```powershell
.\script\docker-setup.ps1
```

**Linux / macOS：**

```bash
chmod +x script/docker-setup.sh
./script/docker-setup.sh
```

## 前置要求

- **Docker Desktop**（Windows/macOS）或 **Docker Engine**（Linux）
- **Docker Compose v2**
- **openclaw-main.zip** 源码包（或设置 `OPENCLAW_IMAGE` 使用远程镜像）
- 至少 **2GB 内存**用于构建镜像
- 足够的磁盘空间存储镜像和日志

## 文件说明

| 文件 | 说明 |
|------|------|
| `docker-setup.ps1` | Windows PowerShell 一键部署脚本 |
| `docker-setup.sh` | Linux/macOS 一键部署脚本 |
| `docker-start.ps1` | 启动 Gateway 容器 |
| `docker-stop.ps1` | 停止 Gateway 容器 |
| `docker-logs.ps1` | 查看 Gateway 日志 |
| `docker-status.ps1` | 查看容器状态和健康检查 |

根目录文件：

| 文件 | 说明 |
|------|------|
| `Dockerfile` | Docker 镜像构建文件 |
| `docker-compose.yml` | Docker Compose 配置 |
| `docker-setup.bat` | Windows 双击启动脚本 |

## 环境变量

在运行部署脚本之前，可以设置以下环境变量自定义配置：

```powershell
# 使用远程镜像（跳过本地构建）
$env:OPENCLAW_IMAGE = "ghcr.io/openclaw/openclaw:latest"

# 自定义端口
$env:OPENCLAW_GATEWAY_PORT = "8080"

# 自定义配置目录
$env:OPENCLAW_CONFIG_DIR = "D:\openclaw-config"

# 运行部署
.\docker\docker-setup.ps1
```

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `OPENCLAW_IMAGE` | `openclaw:local` | Docker 镜像名称 |
| `OPENCLAW_GATEWAY_PORT` | `18789` | Gateway 端口 |
| `OPENCLAW_BRIDGE_PORT` | `18790` | Bridge 端口 |
| `OPENCLAW_GATEWAY_BIND` | `lan` | 绑定模式 |
| `OPENCLAW_CONFIG_DIR` | `~/.openclaw` | 配置目录 |
| `OPENCLAW_WORKSPACE_DIR` | `~/.openclaw/workspace` | 工作区目录 |
| `OPENCLAW_GATEWAY_TOKEN` | 自动生成 | 认证令牌 |

## 常用操作

### 查看状态

```powershell
.\docker\docker-status.ps1
# 或
docker compose ps
```

### 查看日志

```powershell
.\docker\docker-logs.ps1
# 或
docker compose logs -f openclaw-gateway
```

### 停止服务

```powershell
.\docker\docker-stop.ps1
# 或
docker compose stop
```

### 启动服务

```powershell
.\docker\docker-start.ps1
# 或
docker compose start openclaw-gateway
```

### 完全删除

```powershell
docker compose down
# 删除镜像
docker rmi openclaw:local
```

## 访问 Gateway

部署完成后，访问：

```
http://127.0.0.1:18789
```

在设置中输入 Token（显示在部署脚本输出中，或查看 `.env` 文件）。

## 数据持久化

以下目录会挂载到宿主机，容器删除后数据仍然保留：

- `~/.openclaw` — 配置、会话、日志
- `~/.openclaw/workspace` — 工作区文件

## 健康检查

```bash
# Liveness
curl http://127.0.0.1:18789/healthz

# Readiness
curl http://127.0.0.1:18789/readyz
```

## 故障排除

### Docker 构建失败（exit 137）

内存不足，增加 Docker Desktop 的内存分配或使用预构建镜像。

### 端口被占用

设置 `OPENCLAW_GATEWAY_PORT` 为其他端口。

### 权限错误

Windows：确保 Docker Desktop 有访问挂载目录的权限。
Linux：运行 `sudo chown -R 1000:1000 ~/.openclaw`。

### 网络问题

确保 `OPENCLAW_GATEWAY_BIND=lan`（Docker 默认），`loopback` 模式在 Docker 中无法从宿主机访问。
