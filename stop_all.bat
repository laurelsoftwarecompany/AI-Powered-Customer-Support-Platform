@echo off
title Laurel Systems - Stop All Services
echo ============================================================
echo   Stopping Laurel Systems Services (8000, 3000, 8080)
echo ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ports = @(8000, 3000, 8080); " ^
  "foreach ($port in $ports) { " ^
  "  $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue; " ^
  "  if ($conns) { " ^
  "    $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique; " ^
  "    foreach ($p in $pids) { " ^
  "      try { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue; Write-Host \"[STOPPED] Port $port (PID $p)\" -ForegroundColor Green } catch {} " ^
  "    } " ^
  "  } else { " ^
  "    Write-Host \"[OK] Port $port is already free.\" -ForegroundColor Gray " ^
  "  } " ^
  "}"

echo.
echo All services stopped.
echo.
pause
