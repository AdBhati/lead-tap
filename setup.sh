#!/usr/bin/env bash
# setup.sh — Stall Capture full project setup (Mac/Linux)
# Installs all dependencies, runs migrations, and starts both servers.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎯  Stall Capture — Setup Script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Helpers ─────────────────────────────────────────────────────────────────
ok()  { echo "  ✅  $*"; }
info(){ echo "  ℹ️   $*"; }
warn(){ echo "  ⚠️   $*"; }
fail(){ echo "  ❌  $*"; exit 1; }

check_cmd() { command -v "$1" &>/dev/null; }

# ── Check / Install Python 3 ─────────────────────────────────────────────────
if check_cmd python3; then
  PYTHON=$(command -v python3)
  ok "Python 3 found: $(python3 --version)"
else
  warn "Python 3 not found. Attempting to install via Homebrew..."
  if ! check_cmd brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  brew install python3
  PYTHON=$(command -v python3)
  ok "Python 3 installed."
fi

# ── Check / Install pip ───────────────────────────────────────────────────────
if ! "$PYTHON" -m pip --version &>/dev/null; then
  warn "pip not found. Installing..."
  curl https://bootstrap.pypa.io/get-pip.py | "$PYTHON"
  ok "pip installed."
else
  ok "pip found."
fi

# ── Backend Setup ─────────────────────────────────────────────────────────────
echo ""
echo "── Backend Setup ──────────────────────────────────────────"

cd "$BACKEND_DIR"

# Create virtual environment if not exists
if [ ! -d "venv" ]; then
  info "Creating virtual environment..."
  "$PYTHON" -m venv venv
  ok "Virtual environment created."
fi

# Activate venv
source venv/bin/activate
PYTHON="$(pwd)/venv/bin/python"

# Install / upgrade dependencies
info "Installing Python dependencies..."
pip install --upgrade pip -q
pip install -r requirements.txt -q
ok "Python dependencies installed."

# Create .env if not exists
if [ ! -f ".env" ]; then
  cp .env.example .env
  warn "Created backend/.env from .env.example — please fill in GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET."
fi

# Run migrations
info "Running Django migrations..."
"$PYTHON" manage.py migrate --run-syncdb 2>&1 | tail -5
ok "Migrations complete."

# Create superuser if it doesn't exist (non-interactive)
info "Creating default admin user (admin@stallcapture.com / admin123)..."
"$PYTHON" -c "
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'stall_capture.settings')
django.setup()
from api.models import User
if not User.objects.filter(email='admin@stallcapture.com').exists():
    u = User.objects.create_superuser(
        username='admin',
        email='admin@stallcapture.com',
        password='admin123',
        name='Admin'
    )
    print('Superuser created.')
else:
    print('Superuser already exists.')
" 2>/dev/null || true

# ── Check / Install Flutter ──────────────────────────────────────────────────
echo ""
echo "── Frontend Setup ─────────────────────────────────────────"

deactivate 2>/dev/null || true

if check_cmd flutter; then
  ok "Flutter found: $(flutter --version | head -1)"
else
  warn "Flutter SDK not found."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    info "Downloading Flutter SDK for macOS..."
    FLUTTER_ARCHIVE="flutter_macos_arm64-stable.tar.xz"
    FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/${FLUTTER_ARCHIVE}"
    cd "$SCRIPT_DIR"
    curl -O "$FLUTTER_URL"
    tar xf "$FLUTTER_ARCHIVE"
    rm "$FLUTTER_ARCHIVE"
    export PATH="$SCRIPT_DIR/flutter/bin:$PATH"
    echo 'export PATH="'"$SCRIPT_DIR"'/flutter/bin:$PATH"' >> ~/.zshrc
    ok "Flutter SDK installed. You may need to run: source ~/.zshrc"
  else
    warn "Please install Flutter manually: https://flutter.dev/docs/get-started/install"
  fi
fi

# Flutter pub get
cd "$FRONTEND_DIR"
if check_cmd flutter; then
  info "Running flutter pub get..."
  flutter pub get -q
  ok "Flutter dependencies installed."
else
  warn "Flutter not in PATH — skipping pub get. Re-run setup.sh after installing Flutter."
fi

# ── Platform config reminder ─────────────────────────────────────────────────
echo ""
echo "── Google OAuth Configuration ─────────────────────────────"
echo "  Before running, configure the following:"
echo "  1. Google Cloud Console → APIs & Services → Credentials"
echo "     → Create OAuth 2.0 Client ID (Web + Android + iOS)"
echo "  2. Fill in backend/.env:"
echo "       GOOGLE_CLIENT_ID=your-client-id"
echo "       GOOGLE_CLIENT_SECRET=your-client-secret"
echo "  3. For Android: add google-services.json to frontend/android/app/"
echo "  4. For iOS: add GoogleService-Info.plist to frontend/ios/Runner/"
echo ""

# ── Start servers ────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Starting servers..."
echo "  Backend:  http://localhost:8000"
echo "  Django Admin: http://localhost:8000/admin"
echo "  Flutter Web:  http://localhost:3000 (run in separate terminal)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start Django in background
cd "$BACKEND_DIR"
source venv/bin/activate
"$PYTHON" manage.py runserver 8000 &
DJANGO_PID=$!
ok "Django started (PID $DJANGO_PID)"

# Start Flutter Web
cd "$FRONTEND_DIR"
if check_cmd flutter; then
  info "Starting Flutter Web on port 3000..."
  flutter run -d chrome --web-port=3000 &
  FLUTTER_PID=$!
  ok "Flutter Web started (PID $FLUTTER_PID)"
fi

echo ""
echo "  Press Ctrl+C to stop both servers."
echo ""

# Wait for Ctrl+C
trap "kill $DJANGO_PID $FLUTTER_PID 2>/dev/null; echo '  Servers stopped.'" INT TERM
wait
