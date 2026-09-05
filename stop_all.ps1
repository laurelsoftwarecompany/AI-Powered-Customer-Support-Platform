# ==============================================================================
# Laurel Systems — AI Customer Support Platform
# Stop All Services Script (Backend + Web Dashboard + Customer Frontend)
# ==============================================================================

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Stopping Laurel Systems Services (8000, 3000, 8080)       " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

$ports = @(8000, 3000, 8080)
$stoppedAny = $false

foreach ($port in $ports) {
    $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($conns) {
        $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($procId in $pids) {
            try {
                $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
                $procName = if ($p) { $p.ProcessName } else { "PID $procId" }
                Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                Write-Host "  [STOPPED] Service on port $port ($procName, PID $procId)" -ForegroundColor Green
                $stoppedAny = $true
            } catch {
                Write-Host "  [WARN] Failed to stop PID $procId: $_" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  [OK] Port $port is already free." -ForegroundColor Gray
    }
}

Write-Host ""
if ($stoppedAny) {
    Write-Host "All specified services have been stopped." -ForegroundColor Green
} else {
    Write-Host "No active services found on ports 8000, 3000, or 8080." -ForegroundColor Yellow
}
Write-Host ""
