# Check OpenClaw Docker status
$RootDir = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
$ComposeFile = Join-Path $RootDir "docker-compose.yml"

Write-Host "OpenClaw Docker Status" -ForegroundColor Cyan
Write-Host "======================" -ForegroundColor Cyan
Write-Host ""

docker compose -f $ComposeFile ps

Write-Host ""

# Check health
$container = docker ps --filter "name=openclaw-gateway" --format "{{.ID}}" 2>$null
if ($container) {
    Write-Host "Health check:" -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:18789/healthz" -UseBasicParsing -TimeoutSec 5
        Write-Host "  Gateway: OK ($($response.StatusCode))" -ForegroundColor Green
    } catch {
        Write-Host "  Gateway: Not responding" -ForegroundColor Red
    }
} else {
    Write-Host "Gateway container is not running." -ForegroundColor Yellow
}
