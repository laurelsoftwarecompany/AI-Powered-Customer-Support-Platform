# ==============================================================================
# Laurel Systems — AI Customer Support Platform
# Start All Services Script (Backend + Web Dashboard + Customer Frontend)
# ==============================================================================

param (
    [switch]$Background = $false
)

$RootDir = $PSScriptRoot
$BackendDir = Join-Path $RootDir "customer_support_platform\backend"
$WebDir = Join-Path $RootDir "customer_support_platform\web-dashboard"
$MobileDir = Join-Path $RootDir "customer_support_platform\Mobile app"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Starting Laurel Systems - Full AI Customer Support Stack  " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Function to stop any process holding a target port
function Clear-Port([int]$Port) {
    $conns = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if ($conns) {
        $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($procId in $pids) {
            try {
                Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                Write-Host "  [CLEANUP] Stopped process $procId holding port $Port" -ForegroundColor Yellow
            } catch {}
        }
    }
}

# 1. Clean existing instances on 8000, 3000, 8080
Clear-Port 8000
Clear-Port 3000
Clear-Port 8080

# 2. Launch Backend (FastAPI on Port 8000)
Write-Host "  [1/3] Starting Backend API on http://localhost:8000..." -ForegroundColor Green
$BackendPython = Join-Path $BackendDir ".venv\Scripts\python.exe"
if (-not (Test-Path $BackendPython)) {
    $BackendPython = "python"
}

if ($Background) {
    Start-Process -FilePath $BackendPython -ArgumentList "-m uvicorn app.main:app --port 8000 --reload" -WorkingDirectory $BackendDir -WindowStyle Hidden
} else {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$BackendDir'; & '$BackendPython' -m uvicorn app.main:app --port 8000 --reload" -WorkingDirectory $BackendDir
}

# 3. Launch Web Dashboard (Next.js 16 on Port 3000)
Write-Host "  [2/3] Starting Web Dashboard on http://localhost:3000..." -ForegroundColor Green
if ($Background) {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c npm run dev" -WorkingDirectory $WebDir -WindowStyle Hidden
} else {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$WebDir'; npm run dev" -WorkingDirectory $WebDir
}

# 4. Launch Customer Frontend (Flutter Web on Port 8080)
Write-Host "  [3/3] Starting Customer Frontend on http://localhost:8080..." -ForegroundColor Green
if ($Background) {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c flutter run -d chrome --web-port=8080" -WorkingDirectory $MobileDir -WindowStyle Hidden
} else {
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$MobileDir'; flutter run -d chrome --web-port=8080" -WorkingDirectory $MobileDir
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  All 3 services are launching!                             " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  • Backend API:        http://localhost:8000 (Swagger: /docs)" -ForegroundColor White
Write-Host "  • Staff Web Console:  http://localhost:3000" -ForegroundColor White
Write-Host "  • Customer Web App:   http://localhost:8080" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "To stop all services later, run: .\stop_all.ps1" -ForegroundColor Yellow
Write-Host ""
