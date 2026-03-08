# OpenClaw Windows 部署笔记

## 部署文件

| 文件 | 说明 |
|------|------|
| `deploy-windows.bat` | 双击启动 GUI 安装器 |
| `scripts/deploy-windows.ps1` | WPF 向导式安装脚本 |
| `scripts/deploy-windows.env.example` | 部署配置模板 |
| `scripts/windows/start-gateway.ps1` | 启动 Gateway（安装后生成） |
| `scripts/windows/stop-gateway.ps1` | 停止 Gateway |
| `scripts/windows/restart-gateway.ps1` | 重启 Gateway |

## 代码来源选项

安装器支持三种代码来源，适应不同网络环境：

| 来源 | 说明 | 适用场景 |
|------|------|----------|
| **Local Project** | 使用本地已有的项目代码 | 已下载代码 / 离线安装 |
| **GitHub** | 直接从 GitHub 克隆 | 有 VPN / 海外网络 |
| **GitHub Mirror** | 通过 ghproxy.com 代理克隆 | 中国大陆无 VPN |

### 使用本地项目（推荐离线安装）

1. 先通过其他方式获取代码（如从 Gitee 镜像下载、或从 U 盘拷贝）
2. 在项目目录中双击 `deploy-windows.bat`
3. 安装器会自动检测到本地项目，选择 "Use local project"
4. 无需联网即可完成构建和配置

### 使用 GitHub Mirror（中国大陆推荐）

1. 双击 `deploy-windows.bat`
2. 选择 "Clone from GitHub Mirror (ghproxy.com, China-friendly)"
3. 安装器会通过 `ghproxy.com` 代理克隆代码
4. 同时使用 `npmmirror.com` 加速 npm 依赖下载

## 遇到的问题及修复

### 1. PowerShell 5.1 ANSI 转义不兼容

**现象：** 脚本解析报错 `UnexpectedToken`。

**原因：** 原脚本使用 `` `e `` 转义序列生成 ANSI 颜色，该语法仅 PowerShell 7+ 支持。

**修复：** 改用 `Write-Host -ForegroundColor` 替代 ANSI 转义。

### 2. XAML `x:Name` 无法被 FindName() 解析

**现象：** `ShowDialog()` 抛出 `Cannot index into a null array`，所有 `FindName()` 返回 `$null`。

**原因：** PowerShell 通过 `XamlReader::Load()` 加载 XAML 时，`x:Name` 不会在 NameScope 中注册。

**修复：** 将所有 `x:Name="xxx"` 改为 `Name="xxx"`（保留 `x:Key` 不变）。

### 3. WPF 事件回调中 `$script:` 作用域丢失

**现象：** 窗口渲染后立刻崩溃，`DispatcherTimer.FireTick` 中报 `Cannot index into a null array`。

**原因：** PowerShell 5.1 的 WPF 事件分发器回调中，`$script:` 作用域链会断裂，导致事件处理函数无法访问脚本级变量。

**修复：** 将所有 UI 引用和状态存入 `$global:G` 哈希表，事件处理函数统一通过 `$global:G.xxx` 访问。这是 PowerShell WPF 编程的标准模式。

### 4. `-replace` 链在 .NET 方法调用中被拆分

**现象：** `WriteAllText` 报错 `找不到参数计数为 5 的重载`。

**原因：** PowerShell 在 `.NET 方法调用`内部，将 `-replace 'a',$b` 中的逗号解析为方法参数分隔符，而非 `-replace` 运算符的一部分。

```powershell
# 错误写法 — 逗号被当作方法参数分隔
[IO.File]::WriteAllText($path, $str -replace 'A',$a -replace 'B',$b)

# 正确写法 — 先存变量
$content = $str -replace 'A',$a -replace 'B',$b
[IO.File]::WriteAllText($path, $content)
```

### 5. `bash` 指向 WSL 而非 Git Bash 导致构建失败

**现象：** `pnpm build` 第一步 `canvas:a2ui:bundle` 失败，报 `execvpe(/bin/bash) failed: No such file or directory`。

**原因：** Windows PATH 中 `bash` 优先解析到 `C:\Windows\System32\bash.exe`（WSL），而 WSL 未正确安装。Git Bash (`D:\Program Files\Git\bin\bash.exe`) 排在后面。

**修复：** 在安装脚本的后台构建逻辑中，检测 Git 安装路径并将 `Git\bin` 加到 PATH 最前面：

```powershell
$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if ($gitCmd) {
    $gitBash = Join-Path (Split-Path (Split-Path $gitCmd.Source) -Parent) "bin"
    if (Test-Path (Join-Path $gitBash "bash.exe")) {
        $env:Path = "$gitBash;$($env:Path)"
    }
}
```

### 6. Control UI `device signature invalid`

**现象：** 浏览器 Dashboard 连接 Gateway 时报 `device signature invalid` 或 `gateway token missing`。

**原因：** Control UI 使用 Web Crypto API 生成设备密钥对并签名连接请求，在某些 Windows 浏览器环境下签名验证失败。

**修复：**

```powershell
# 临时禁用设备签名验证（localhost 绑定下安全风险低）
openclaw config set gateway.controlUi.dangerouslyDisableDeviceAuth true

# 设置允许的来源
openclaw config set gateway.controlUi.allowedOrigins '["http://127.0.0.1:18789"]' --strict-json

# 重启 Gateway 后生效
```

**注意：** 访问 Dashboard 必须使用带 token 的完整 URL：

```
http://127.0.0.1:18789/#token=<your-token>
```

可通过 `openclaw dashboard --no-open` 获取。

## 配置火山引擎（Volcengine / 豆包）

1. 写入 API Key 到 auth profile：

```powershell
# 文件位置: ~/.openclaw/agents/main/agent/auth-profiles.json
{
  "profiles": {
    "volcengine:default": {
      "type": "api_key",
      "provider": "volcengine",
      "key": "<your-volcengine-api-key>"
    }
  }
}
```

2. 设置默认模型：

```powershell
openclaw config set agents.defaults.model "volcengine/doubao-seed-1-8-251228"
```

3. 可选模型列表（火山引擎）：

| 模型 ID | 说明 |
|---------|------|
| `doubao-seed-1-8-251228` | 豆包 Seed 1.8（默认） |
| `doubao-seed-code-preview-251028` | 豆包代码预览 |
| `deepseek-v3-2-251201` | DeepSeek V3.2 |
| `kimi-k2-5` | Kimi K2.5 |
| `glm-4-7` | GLM-4-7 |

API 端点：`https://ark.cn-beijing.volces.com/api/v3`

## Windows 上安装 Skills 依赖

Skills 的安装定义通常只列了 `brew`（macOS）和 `apt`（Linux），Windows 需要手动用 `winget` 安装对应 CLI 工具。

### 7. Skill 报 `brew not installed`

**现象：** 安装 skill（如 🐙 github）时报 `brew not installed — Homebrew is not installed`。

**原因：** Skill 元数据中 `install` 只定义了 `brew` 和 `apt` 两种安装方式，没有 Windows 对应项。

**修复：** 在 Windows 上用 `winget` 手动安装 skill 所需的 CLI 工具：

```powershell
# 🐙 github skill — 需要 gh CLI
winget install GitHub.cli

# 安装后刷新 PATH
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")

# 验证
gh --version
```

### 常用 Skill 的 Windows 安装命令

| Skill | 依赖 CLI | Windows 安装命令 |
|-------|----------|-----------------|
| 🐙 github | `gh` | `winget install GitHub.cli` |
| 📦 gh-issues | `gh` | `winget install GitHub.cli` |
| 🧩 coding-agent | `codex` / `claude` | 参考各自官方文档 |
| 📝 notion | `notion` | `npm install -g notion-cli` |
| 🎞 video-frames | `ffmpeg` | `winget install Gyan.FFmpeg` |
| 🧾 summarize | `yt-dlp` | `winget install yt-dlp.yt-dlp` |
| 📄 nano-pdf | `nano-pdf` | `npm install -g nano-pdf` |

安装完依赖后运行 `openclaw skills list` 确认状态变为 `ready`。

### 8. Dashboard 刷新后断开连接（token 丢失 / device identity required）

**现象：** 首次通过 `openclaw dashboard` 打开的带 `#token=xxx` URL 可以连接，但刷新页面后报 `device identity required` 或 `gateway token missing`，状态变为 Offline。

**原因：** Token 认证模式下，token 通过 URL 片段 `#token=xxx` 传递。浏览器刷新后 URL 片段丢失，Control UI 无法重新认证。

**修复：** 改用密码认证模式。密码会被 Control UI 持久化到浏览器 localStorage，刷新不会丢失。

```powershell
# 切换为密码认证
openclaw config set gateway.auth.mode password
openclaw config set gateway.auth.password <你的密码>

# 重启 Gateway 生效
# (用 scripts\windows\restart-gateway.ps1 或手动重启)
```

修改后：
1. 浏览器访问 `http://127.0.0.1:18789`
2. 在 **Password** 输入框填入密码
3. 点击 **Connect**

刷新页面后会自动重连，不需要重新输入。

### 9. 如何查看 Gateway Token / Password

**场景：** 忘记 Gateway 的认证凭据（token 或 password），或需要在新浏览器中访问 Dashboard。

**方法一：命令行查看**

```powershell
# 查看完整认证配置
openclaw config get gateway.auth
```

**方法二：直接查看配置文件**

```powershell
# 配置文件位置
notepad %USERPROFILE%\.openclaw\openclaw.json
```

在 `gateway.auth` 段中可以找到：
- `mode` — 认证模式（`none` / `token` / `password`）
- `token` — Gateway Token
- `password` — 密码（仅 password 模式下使用）

**方法三：获取带 Token 的 Dashboard URL**

```powershell
openclaw dashboard --no-open
```

输出示例：

```
Dashboard URL: http://127.0.0.1:18789/#token=99284ac2...
```

直接复制该 URL 到浏览器即可访问。

### 10. GitHub 克隆失败（网络问题）

**现象：** 安装过程中 `git clone` 失败，报错 `fatal: unable to access` 或超时。

**原因：** 中国大陆直接访问 GitHub 可能被阻断或速度极慢。

**修复方案：**

**方案 A：使用 GitHub Mirror（推荐）**

重新运行安装器，在 "Install Location" 页面选择：
> Clone from GitHub Mirror (ghproxy.com, China-friendly)

安装器会通过 `ghproxy.com` 代理克隆，同时使用 `npmmirror.com` 加速依赖下载。

**方案 B：使用本地项目**

1. 从其他来源获取代码（如 Gitee 镜像、网盘分享、U 盘拷贝）
2. 解压到目标目录（如 `C:\Users\你的用户名\openclaw`）
3. 在该目录运行 `deploy-windows.bat`
4. 安装器会检测到本地项目，选择 "Use local project"

**方案 C：配置 Git 代理**

如果有 HTTP 代理（如 Clash），可以配置 Git 使用代理：

```powershell
# 设置 HTTP 代理（以 Clash 默认端口为例）
git config --global http.proxy http://127.0.0.1:7890
git config --global https.proxy http://127.0.0.1:7890

# 取消代理
git config --global --unset http.proxy
git config --global --unset https.proxy
```

---

## 四、打包为独立 EXE

OpenClaw 提供了将 PowerShell 脚本打包为独立 EXE 的功能，方便分发和使用。

### 1. 打包方式

双击项目根目录的 `build-exe.bat`，或在 PowerShell 中运行：

```powershell
.\scripts\build-exe.ps1
```

### 2. 打包输出

打包完成后，EXE 文件位于 `dist/` 目录：

| 文件 | 说明 |
|------|------|
| `OpenClaw-Installer.exe` | GUI 安装向导 |
| `OpenClaw-Config-Manager.exe` | 配置管理器 |

### 3. 打包依赖

打包使用 [PS2EXE](https://github.com/MScholtes/PS2EXE) 模块：

- 首次运行会自动安装（需要网络）
- 手动安装：`Install-Module -Name ps2exe -Scope CurrentUser`

### 4. 打包参数

`scripts/build-exe.ps1` 使用以下参数：

| 参数 | 值 | 说明 |
|------|-----|------|
| `-NoConsole` | `$true` | 无控制台窗口，直接显示 GUI |
| `-STA` | `$true` | 单线程单元模式，WPF 必需 |
| `-RequireAdmin` | `$false` | 不需要管理员权限 |

### 5. EXE 路径处理

编译为 EXE 后，`$PSScriptRoot` 会变成空字符串。脚本通过 `Get-ScriptDirectory` 函数处理：

```powershell
function Get-ScriptDirectory {
    # 1. 尝试 $PSScriptRoot（正常 ps1 执行）
    if ($PSScriptRoot -and $PSScriptRoot -ne "") { return $PSScriptRoot }
    
    # 2. 尝试 $MyInvocation（兼容旧版 PowerShell）
    if ($MyInvocation.MyCommand.Path) { 
        return Split-Path $MyInvocation.MyCommand.Path -Parent 
    }
    
    # 3. 使用 EXE 实际位置（编译后执行）
    $exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($exePath -and (Test-Path $exePath)) {
        $exeDir = Split-Path $exePath -Parent
        # 如果 EXE 在 dist/ 目录，向上查找 scripts/
        if ((Split-Path $exeDir -Leaf) -eq "dist") { 
            return Join-Path (Split-Path $exeDir -Parent) "scripts" 
        }
        return $exeDir
    }
    
    # 4. 回退到当前目录
    return (Get-Location).Path
}
```

### 6. 分发注意事项

- EXE 内嵌 PowerShell 脚本，运行时仍需要系统安装 PowerShell 5.1+
- Windows 10/11 自带 PowerShell，无需额外安装
- 某些杀毒软件可能误报 PS2EXE 生成的 EXE，可添加白名单
- 如需完全独立运行（无 PowerShell 依赖），考虑使用 .NET 重写
