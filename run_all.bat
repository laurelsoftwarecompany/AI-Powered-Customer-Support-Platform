@echo off
title Laurel Systems - AI Support Platform Runner
echo ============================================================
echo   Starting Laurel Systems - Full Stack Runner
echo ============================================================
echo.

set "ROOT_DIR=%~dp0"
set "BACKEND_DIR=%ROOT_DIR%customer_support_platform\backend"
set "WEB_DIR=%ROOT_DIR%customer_support_platform\web-dashboard"
set "MOBILE_DIR=%ROOT_DIR%customer_support_platform\Mobile app"

:: Free ports 8000, 3000, 8080 if currently in use
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT_DIR%stop_all.ps1"

:: Locate Python virtualenv
if exist "%BACKEND_DIR%\.venv\Scripts\python.exe" (
    set "PYTHON_EXE=%BACKEND_DIR%\.venv\Scripts\python.exe"
) else (
    set "PYTHON_EXE=python"
)

echo [1/3] Starting Backend API (FastAPI - Port 8000)...
start "Backend API (Port 8000)" cmd /k "cd /d "%BACKEND_DIR%" && "%PYTHON_EXE%" -m uvicorn app.main:app --port 8000 --reload"

echo [2/3] Starting Web Dashboard (Next.js - Port 3000)...
start "Staff Web Dashboard (Port 3000)" cmd /k "cd /d "%WEB_DIR%" && npm run dev"

echo [3/3] Starting Customer App (Flutter Web - Port 8080)...
start "Customer App (Port 8080)" cmd /k "cd /d "%MOBILE_DIR%" && flutter run -d chrome --web-port=8080"

echo.
echo ============================================================
echo   All 3 services have been launched in separate windows!
echo   - Backend API:       http://localhost:8000 (Docs: /docs)
echo   - Staff Web Portal:  http://localhost:3000
echo   - Customer App:      http://localhost:8080
echo ============================================================
echo.
echo To stop everything, run stop_all.bat or stop_all.ps1
echo.
pause
