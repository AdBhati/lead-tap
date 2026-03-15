#!/bin/bash
# Unified Deployment Script for Stall Capture
# This script does everything: setup, configuration, and deployment

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀  Stall Capture — Complete Deployment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok() { echo -e "${GREEN}✅${NC} $*"; }
info() { echo -e "${BLUE}ℹ️${NC} $*"; }
warn() { echo -e "${YELLOW}⚠️${NC} $*"; }
error() { echo -e "${RED}❌${NC} $*"; exit 1; }

# Configuration
PROJECT_DIR="/home/ubuntu/stall-capture"
BACKEND_DIR="$PROJECT_DIR/backend"
ENV_FILE="$BACKEND_DIR/.env"
DOMAIN_NAME=""
SUPABASE_PASSWORD=""
R2_ACCESS_KEY=""
R2_SECRET_KEY=""
R2_BUCKET_NAME="stall-capture-media"
GOOGLE_CLIENT_ID=""
GOOGLE_CLIENT_SECRET=""
FRONTEND_DOMAIN=""

# Function to prompt for input
prompt_input() {
    local prompt_text=$1
    local var_name=$2
    local value
    read -p "$prompt_text: " value
    eval "$var_name='$value'"
}

prompt_secret() {
    local prompt_text=$1
    local var_name=$2
    local value
    read -sp "$prompt_text: " value
    echo ""
    eval "$var_name='$value'"
}

# Check if running as ubuntu user
if [ "$USER" != "ubuntu" ]; then
    error "This script must be run as the ubuntu user"
fi

# ─── Step 1: Collect Credentials ────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📝  Step 1: Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "You can use either:"
info "  1. Custom domain (e.g., example.com) - Recommended for production"
info "  2. EC2 Public DNS (e.g., ec2-13-230-148-121.ap-southeast-1.compute.amazonaws.com)"
echo ""

# Get EC2 Public DNS automatically
EC2_PUBLIC_DNS=$(curl -s http://169.254.169.254/latest/meta-data/public-hostname 2>/dev/null || echo "")
if [ -n "$EC2_PUBLIC_DNS" ]; then
    info "Detected EC2 Public DNS: $EC2_PUBLIC_DNS"
    prompt_input "Enter domain name or press Enter to use EC2 Public DNS [$EC2_PUBLIC_DNS]" DOMAIN_NAME
    DOMAIN_NAME=${DOMAIN_NAME:-$EC2_PUBLIC_DNS}
    USE_PUBLIC_DNS=true
else
    prompt_input "Enter your domain name (or EC2 Public DNS)" DOMAIN_NAME
    USE_PUBLIC_DNS=false
fi
prompt_secret "Enter Supabase database password" SUPABASE_PASSWORD
prompt_input "Enter Cloudflare R2 Access Key ID" R2_ACCESS_KEY
prompt_secret "Enter Cloudflare R2 Secret Access Key" R2_SECRET_KEY
prompt_input "Enter R2 Bucket Name" R2_BUCKET_NAME
prompt_input "Enter Google OAuth Client ID" GOOGLE_CLIENT_ID
prompt_secret "Enter Google OAuth Client Secret" GOOGLE_CLIENT_SECRET
prompt_input "Enter Frontend Domain for CORS (e.g., https://yourdomain.com)" FRONTEND_DOMAIN

# Generate secure keys
info "Generating secure keys..."
DJANGO_SECRET_KEY=$(python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())" 2>/dev/null || openssl rand -base64 50)
ENCRYPTION_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || openssl rand -base64 32)

# Database URL
DATABASE_URL="postgresql://postgres:${SUPABASE_PASSWORD}@db.wuuhcxrmjdfyowjdsmar.supabase.co:5432/postgres"
R2_ENDPOINT_URL="https://5814ddfac596cf207d3c83e60cfa0b4c.r2.cloudflarestorage.com"

ok "Configuration collected"

# ─── Step 2: System Setup ───────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🛠️  Step 2: System Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

info "Installing required packages..."
sudo apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3-pip \
    postgresql-client \
    nginx \
    certbot \
    python3-certbot-nginx \
    git \
    curl \
    build-essential \
    libpq-dev \
    python3-dev > /dev/null 2>&1

ok "System packages installed"

# ─── Step 3: Project Setup ──────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📦  Step 3: Project Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || error "Failed to access project directory"

# Check if backend exists
if [ ! -d "$BACKEND_DIR" ]; then
    error "Backend directory not found. Please upload files first."
fi

cd "$BACKEND_DIR"

# Create virtual environment if not exists
if [ ! -d "venv" ]; then
    info "Creating virtual environment..."
    python3.11 -m venv venv
    ok "Virtual environment created"
fi

# Activate venv
source venv/bin/activate

# Install dependencies
info "Installing Python dependencies..."
pip install --upgrade pip 'setuptools<70' wheel -q
pip install -r requirements.txt -q

ok "Dependencies installed"

# ─── Step 4: Environment Configuration ──────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ⚙️  Step 4: Environment Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "Creating .env file..."
cat > "$ENV_FILE" << EOF
# Django Settings
DEBUG=False
SECRET_KEY=$DJANGO_SECRET_KEY
ALLOWED_HOSTS=$DOMAIN_NAME,www.$DOMAIN_NAME

# Database (Supabase PostgreSQL)
DATABASE_URL=$DATABASE_URL

# Cloudflare R2 Storage
USE_R2=True
R2_ACCESS_KEY_ID=$R2_ACCESS_KEY
R2_SECRET_ACCESS_KEY=$R2_SECRET_KEY
R2_BUCKET_NAME=$R2_BUCKET_NAME
R2_ENDPOINT_URL=$R2_ENDPOINT_URL
R2_CUSTOM_DOMAIN=

# Google OAuth
GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET=$GOOGLE_CLIENT_SECRET

# CORS
CORS_ALLOWED_ORIGINS=$FRONTEND_DOMAIN

# Encryption
FIELD_ENCRYPTION_KEY=$ENCRYPTION_KEY

# Email Configuration
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
EMAIL_HOST=
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
DEFAULT_FROM_EMAIL=noreply@$DOMAIN_NAME

# SSL Settings
SECURE_SSL_REDIRECT=True
EOF

chmod 600 "$ENV_FILE"
ok ".env file created"

# ─── Step 5: Database Setup ──────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🗄️  Step 5: Database Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "Running database migrations..."
export DJANGO_SETTINGS_MODULE=stall_capture.settings_production
python manage.py migrate --noinput

ok "Database migrations completed"

# ─── Step 6: Static Files ─────────────────────────────────────────────────────
echo ""
info "Collecting static files..."
python manage.py collectstatic --noinput --clear

ok "Static files collected"

# ─── Step 7: Nginx Configuration ────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🌐  Step 7: Nginx Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/stall-capture > /dev/null << 'NGINX_EOF'
upstream django {
    server 127.0.0.1:8000;
}

limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/s;

server {
    listen 80;
    server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;

    ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    access_log /var/log/nginx/stall_capture_access.log;
    error_log /var/log/nginx/stall_capture_error.log;

    client_max_body_size 10M;

    location /static/ {
        alias /home/ubuntu/stall-capture/backend/staticfiles/;
        expires 30d;
    }

    location /media/ {
        alias /home/ubuntu/stall-capture/backend/media/;
        expires 7d;
    }

    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        proxy_pass http://django;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
    }

    location /api/auth/ {
        limit_req zone=auth_limit burst=10 nodelay;
        proxy_pass http://django;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location ~ ^/(swagger|redoc|swagger\.json|swagger\.yaml) {
        proxy_pass http://django;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /admin/ {
        proxy_pass http://django;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health/ {
        access_log off;
        proxy_pass http://django;
        proxy_set_header Host $host;
    }

    location / {
        proxy_pass http://django;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF

# Replace domain placeholder
sudo sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN_NAME/g" /etc/nginx/sites-available/stall-capture

# Enable site
sudo ln -sf /etc/nginx/sites-available/stall-capture /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t && ok "Nginx configured" || error "Nginx configuration error"

# ─── Step 8: Gunicorn Service ───────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔧  Step 8: Gunicorn Service Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "Creating Gunicorn service..."
sudo tee /etc/systemd/system/gunicorn.service > /dev/null << EOF
[Unit]
Description=Gunicorn daemon for Stall Capture Django application
After=network.target

[Service]
User=ubuntu
Group=www-data
WorkingDirectory=$BACKEND_DIR
Environment="PATH=$BACKEND_DIR/venv/bin"
Environment="DJANGO_SETTINGS_MODULE=stall_capture.settings_production"
ExecStart=$BACKEND_DIR/venv/bin/gunicorn \
    --config $BACKEND_DIR/gunicorn_config.py \
    stall_capture.wsgi:application

Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable gunicorn

ok "Gunicorn service configured"

# ─── Step 9: Create Logs Directory ──────────────────────────────────────────
mkdir -p "$BACKEND_DIR/logs"
chmod 755 "$BACKEND_DIR/logs"

# ─── Step 10: SSL Certificate ────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔒  Step 10: SSL Certificate"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if using Public DNS (no SSL for Public DNS)
if [[ "$DOMAIN_NAME" == *"amazonaws.com"* ]] || [[ "$DOMAIN_NAME" == *"compute.amazonaws.com"* ]]; then
    warn "Using EC2 Public DNS - SSL certificate will not be installed"
    warn "Public DNS uses HTTP only (not HTTPS)"
    info "For HTTPS, you need a custom domain name"
    
    # Update Nginx to use HTTP only
    sudo sed -i 's/listen 443 ssl http2;/listen 80;/' /etc/nginx/sites-available/stall-capture
    sudo sed -i '/ssl_certificate/d' /etc/nginx/sites-available/stall-capture
    sudo sed -i '/return 301 https/d' /etc/nginx/sites-available/stall-capture
    sudo sed -i '/server {/,/listen 80;/d' /etc/nginx/sites-available/stall-capture
    
    # Remove www subdomain for Public DNS
    sudo sed -i "s/www\.$DOMAIN_NAME/$DOMAIN_NAME/g" /etc/nginx/sites-available/stall-capture
    
    ok "Nginx configured for HTTP (Public DNS)"
else
    info "Checking DNS configuration..."
    EC2_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip)
    
    if dig +short "$DOMAIN_NAME" | grep -q "$EC2_IP"; then
        ok "DNS is pointing to this server"
        
        info "Installing SSL certificate..."
        sudo certbot --nginx -d "$DOMAIN_NAME" -d "www.$DOMAIN_NAME" \
            --non-interactive --agree-tos \
            --email "admin@$DOMAIN_NAME" \
            --redirect || warn "SSL installation failed. Run manually: sudo certbot --nginx -d $DOMAIN_NAME"
    else
        warn "DNS is not pointing to this server yet."
        info "Current server IP: $EC2_IP"
        info "Please configure DNS first, then run:"
        echo "  sudo certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME"
    fi
fi

# ─── Step 11: Start Services ────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀  Step 11: Starting Services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

info "Starting Gunicorn..."
sudo systemctl start gunicorn
sudo systemctl status gunicorn --no-pager -l | head -10

info "Starting Nginx..."
sudo systemctl start nginx
sudo systemctl enable nginx

# ─── Step 12: Health Check ────────────────────────────────────────────────────
echo ""
info "Waiting for services to start..."
sleep 5

if curl -f http://localhost:8000/health/ > /dev/null 2>&1; then
    ok "Application is running successfully!"
else
    warn "Health check failed. Check logs: sudo journalctl -u gunicorn -n 50"
fi

# ─── Final Summary ───────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅  Deployment Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ok "Your application should be accessible at:"
if [[ "$DOMAIN_NAME" == *"amazonaws.com"* ]] || [[ "$DOMAIN_NAME" == *"compute.amazonaws.com"* ]]; then
    echo "  • http://$DOMAIN_NAME"
    echo "  • http://$DOMAIN_NAME/swagger/"
    echo "  • http://$DOMAIN_NAME/admin/"
    warn "Note: Using HTTP (not HTTPS) with Public DNS"
else
    echo "  • https://$DOMAIN_NAME"
    echo "  • https://$DOMAIN_NAME/swagger/"
    echo "  • https://$DOMAIN_NAME/admin/"
fi
echo ""
info "Useful commands:"
echo "  View logs: sudo journalctl -u gunicorn -f"
echo "  Restart: sudo systemctl restart gunicorn"
echo "  Check status: sudo systemctl status gunicorn"
echo ""
warn "IMPORTANT: Keep your .env file secure!"
echo ""
