# OpenClaw Docker One-Click Setup (Windows)
# Usage: .\docker\docker-setup.ps1
#
# Environment variables:
#   OPENCLAW_IMAGE           - Use remote image instead of building
#   OPENCLAW_GATEWAY_PORT    - Gateway port (default: 18789)
#   OPENCLAW_GATEWAY_BIND    - Bind mode: lan/loopback (default: lan)
#   OPENCLAW_CONFIG_DIR      - Config directory (default: ~/.openclaw)
#   OPENCLAW_WORKSPACE_DIR   - Workspace directory (default: ~/.openclaw/workspace)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent          # docker\script
$DockerDir = Split-Path $ScriptDir -Parent                            # docker
$RootDir = Split-Path $DockerDir -Parent                              # project root
$ComposeFile = Join-Path $DockerDir "docker-compose.yml"
$DockerFile = Join-Path $DockerDir "Dockerfile"
$ImageName = if ($env:OPENCLAW_IMAGE) { $env:OPENCLAW_IMAGE } else { "openclaw:local" }

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "         OpenClaw Docker One-Click Setup (Windows)             " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker
try {
    $null = docker --version
} catch {
    Write-Host "ERROR: Docker is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

try {
    $null = docker compose version
} catch {
    Write-Host "ERROR: Docker Compose v2 not available." -ForegroundColor Red
    exit 1
}

# Configuration
$ConfigDir = if ($env:OPENCLAW_CONFIG_DIR) { $env:OPENCLAW_CONFIG_DIR } else { Join-Path $env:USERPROFILE ".openclaw" }
$WorkspaceDir = if ($env:OPENCLAW_WORKSPACE_DIR) { $env:OPENCLAW_WORKSPACE_DIR } else { Join-Path $ConfigDir "workspace" }
$GatewayPort = if ($env:OPENCLAW_GATEWAY_PORT) { $env:OPENCLAW_GATEWAY_PORT } else { "18789" }
$BridgePort = if ($env:OPENCLAW_BRIDGE_PORT) { $env:OPENCLAW_BRIDGE_PORT } else { "18790" }
$GatewayBind = if ($env:OPENCLAW_GATEWAY_BIND) { $env:OPENCLAW_GATEWAY_BIND } else { "lan" }

# Generate or read token
$GatewayToken = $env:OPENCLAW_GATEWAY_TOKEN
if (-not $GatewayToken) {
    $configFile = Join-Path $ConfigDir "openclaw.json"
    if (Test-Path $configFile) {
        try {
            $cfg = Get-Content $configFile -Raw | ConvertFrom-Json
            if ($cfg.gateway.auth.token) {
                $GatewayToken = $cfg.gateway.auth.token
                Write-Host "Reusing gateway token from config" -ForegroundColor Green
            }
        } catch { }
    }
    
    if (-not $GatewayToken) {
        $GatewayToken = -join ((1..32) | ForEach-Object { "{0:x2}" -f (Get-Random -Maximum 256) })
        Write-Host "Generated new gateway token" -ForegroundColor Green
    }
}

# Set environment variables for docker-compose
$env:OPENCLAW_CONFIG_DIR = $ConfigDir
$env:OPENCLAW_WORKSPACE_DIR = $WorkspaceDir
$env:OPENCLAW_GATEWAY_PORT = $GatewayPort
$env:OPENCLAW_BRIDGE_PORT = $BridgePort
$env:OPENCLAW_GATEWAY_BIND = $GatewayBind
$env:OPENCLAW_GATEWAY_TOKEN = $GatewayToken
$env:OPENCLAW_IMAGE = $ImageName

# Create directories
Write-Host "Creating directories..." -ForegroundColor Yellow
$dirs = @(
    $ConfigDir,
    $WorkspaceDir,
    (Join-Path $ConfigDir "identity"),
    (Join-Path $ConfigDir "agents\main\agent"),
    (Join-Path $ConfigDir "agents\main\sessions"),
    (Join-Path $ConfigDir "logs")
)
foreach ($d in $dirs) {
    if (-not (Test-Path $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }
}

# Write .env file
$envFile = Join-Path $DockerDir ".env"
Write-Host "Writing .env file..." -ForegroundColor Yellow
@"
OPENCLAW_CONFIG_DIR=$ConfigDir
OPENCLAW_WORKSPACE_DIR=$WorkspaceDir
OPENCLAW_GATEWAY_PORT=$GatewayPort
OPENCLAW_BRIDGE_PORT=$BridgePort
OPENCLAW_GATEWAY_BIND=$GatewayBind
OPENCLAW_GATEWAY_TOKEN=$GatewayToken
OPENCLAW_IMAGE=$ImageName
"@ | Out-File -FilePath $envFile -Encoding utf8

# Build or pull image
if ($ImageName -eq "openclaw:local") {
    # Look for source code zip in docker directory
    $SourceZip = Get-ChildItem -Path $DockerDir -Filter "openclaw*.zip" | Select-Object -First 1
    
    if ($SourceZip) {
        Write-Host "Found source archive: $($SourceZip.Name)" -ForegroundColor Green
        
        # Extract to temp directory
        $TempExtract = Join-Path ([System.IO.Path]::GetTempPath()) "openclaw-docker-build-$([guid]::NewGuid().ToString().Substring(0,8))"
        Write-Host "Extracting to: $TempExtract" -ForegroundColor Yellow
        
        Expand-Archive -Path $SourceZip.FullName -DestinationPath $TempExtract -Force
        
        # Find the extracted folder (usually openclaw-main or openclaw-master)
        $ExtractedDir = Get-ChildItem -Path $TempExtract -Directory | Select-Object -First 1
        if (-not $ExtractedDir) {
            Write-Host "ERROR: Could not find extracted directory." -ForegroundColor Red
            exit 1
        }
        
        $BuildContext = $ExtractedDir.FullName
        Write-Host "Build context: $BuildContext" -ForegroundColor Gray
        
        # Copy Dockerfile to build context
        Copy-Item -Path $DockerFile -Destination (Join-Path $BuildContext "Dockerfile") -Force
        
        Write-Host "Building Docker image: $ImageName" -ForegroundColor Yellow
        docker build -t $ImageName $BuildContext
        
        if ($LASTEXITCODE -ne 0) {
            Remove-Item -Path $TempExtract -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "ERROR: Docker build failed." -ForegroundColor Red
            exit 1
        }
        
        # Cleanup temp directory
        Remove-Item -Path $TempExtract -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Cleaned up temp files." -ForegroundColor Gray
    } else {
        Write-Host "ERROR: No source code found." -ForegroundColor Red
        Write-Host "Please place openclaw-main.zip in the docker/ directory," -ForegroundColor Yellow
        Write-Host "or set OPENCLAW_IMAGE to use a remote image." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "Pulling Docker image: $ImageName" -ForegroundColor Yellow
    docker pull $ImageName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Docker pull failed." -ForegroundColor Red
        exit 1
    }
}

# Run onboarding
Write-Host ""
Write-Host "==> Running onboarding (interactive)" -ForegroundColor Cyan
docker compose -f $ComposeFile --profile cli run --rm openclaw-cli onboard --mode local --no-install-daemon

# Start gateway
Write-Host ""
Write-Host "==> Starting gateway" -ForegroundColor Cyan
docker compose -f $ComposeFile up -d openclaw-gateway

# Summary
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                    Setup Complete!                             " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Gateway URL:   http://127.0.0.1:$GatewayPort" -ForegroundColor Cyan
Write-Host "Config:        $ConfigDir" -ForegroundColor Cyan
Write-Host "Workspace:     $WorkspaceDir" -ForegroundColor Cyan
Write-Host "Token:         $GatewayToken" -ForegroundColor Cyan
Write-Host ""
Write-Host "Commands:" -ForegroundColor Yellow
Write-Host "  docker compose logs -f openclaw-gateway     # View logs"
Write-Host "  docker compose stop openclaw-gateway        # Stop gateway"
Write-Host "  docker compose start openclaw-gateway       # Start gateway"
Write-Host "  docker compose down                         # Remove containers"
Write-Host ""
