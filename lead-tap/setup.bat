@echo off
REM setup.bat — Stall Capture full project setup (Windows)
REM Run this from the project root directory.

SETLOCAL ENABLEDELAYEDEXPANSION
SET SCRIPT_DIR=%~dp0
SET BACKEND_DIR=%SCRIPT_DIR%backend
SET FRONTEND_DIR=%SCRIPT_DIR%frontend

echo ─────────────────────────────────────────────────────
echo    Stall Capture — Setup Script (Windows)
echo ─────────────────────────────────────────────────────

REM ── Check Python ──────────────────────────────────────────────────────────
python --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo Python not found. Downloading installer...
    curl -o python_installer.exe https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe
    python_installer.exe /quiet InstallAllUsers=1 PrependPath=1
    del python_installer.exe
    echo Python installed.
) ELSE (
    echo Python found.
)

REM ── Backend ───────────────────────────────────────────────────────────────
cd /d "%BACKEND_DIR%"

IF NOT EXIST "venv" (
    echo Creating virtual environment...
    python -m venv venv
)

call venv\Scripts\activate.bat

echo Installing Python dependencies...
pip install --upgrade pip -q
pip install -r requirements.txt -q
echo Dependencies installed.

IF NOT EXIST ".env" (
    copy .env.example .env
    echo Created backend\.env — please fill in GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET.
)

echo Running Django migrations...
python manage.py migrate --run-syncdb

echo Creating default admin user...
python -c "import os,django; os.environ.setdefault('DJANGO_SETTINGS_MODULE','stall_capture.settings'); django.setup(); from api.models import User; User.objects.filter(email='admin@stallcapture.com').exists() or User.objects.create_superuser(username='admin',email='admin@stallcapture.com',password='admin123',name='Admin')" 2>nul

REM ── Check Flutter ─────────────────────────────────────────────────────────
cd /d "%FRONTEND_DIR%"
flutter --version >nul 2>&1
IF %ERRORLEVEL% EQ 0 (
    echo Running flutter pub get...
    flutter pub get -q
    echo Flutter dependencies installed.
) ELSE (
    echo Flutter not found. Please download from: https://flutter.dev/docs/get-started/install/windows
    echo After installing Flutter, re-run this script.
)

echo ─────────────────────────────────────────────────────
echo Google OAuth Configuration:
echo  1. Visit Google Cloud Console and create OAuth 2.0 credentials
echo  2. Edit backend\.env with your GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET
echo ─────────────────────────────────────────────────────
echo Starting Django backend on http://localhost:8000 ...
echo.

start "Django Backend" cmd /k "cd /d %BACKEND_DIR% && call venv\Scripts\activate.bat && python manage.py runserver 8000"

IF flutter --version >nul 2>&1 (
    start "Flutter Web" cmd /k "cd /d %FRONTEND_DIR% && flutter run -d chrome --web-port=3000"
)

echo Both servers are starting in separate windows.
pause
ENDLOCAL
