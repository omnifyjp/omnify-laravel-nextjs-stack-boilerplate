#!/bin/bash

# Laravel + Next.js Stack Setup

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
STUBS_DIR="$SCRIPT_DIR/stubs"

cd "$ROOT_DIR"

# Parse arguments
FORCE_CONFIG=false
if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
    FORCE_CONFIG=true
fi

# Create .env from .env.example if not exists
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "Created .env from .env.example"
fi

# Load environment variables
source .env

# Set defaults
BASE_DOMAIN=${BASE_DOMAIN:-$(basename "$(dirname "$ROOT_DIR")")}
FRONTEND_PORT=${FRONTEND_PORT:-3000}

echo "Stack: Laravel + Next.js"
echo "Domain: $BASE_DOMAIN"
echo "Frontend Port: $FRONTEND_PORT"
if [ "$FORCE_CONFIG" = true ]; then
    echo "Mode: --force (config only)"
fi
echo ""

# ============================================================
# Helper: Replace placeholders in stub file
# ============================================================
render_stub() {
    local stub_file="$1"
    local app_key="${2:-}"
    
    sed -e "s/{{BASE_DOMAIN}}/$BASE_DOMAIN/g" \
        -e "s/{{APP_KEY}}/$app_key/g" \
        "$stub_file"
}

# ============================================================
# Function: Update config files only
# ============================================================
update_config() {
    echo "Updating configuration files..."
    
    # Backend .env
    if [ -d "backend" ]; then
        # Preserve APP_KEY
        APP_KEY=$(grep "^APP_KEY=" backend/.env 2>/dev/null | cut -d'=' -f2 || echo "")
        
        render_stub "$STUBS_DIR/backend.env.stub" "$APP_KEY" > backend/.env
        echo "✓ backend/.env"
        
        # Generate key if empty
        if [ -z "$APP_KEY" ]; then
            cd backend && php artisan key:generate --force && cd ..
        fi
    fi
    
    # Frontend .env.local
    if [ -d "frontend" ]; then
        render_stub "$STUBS_DIR/frontend.env.stub" > frontend/.env.local
        echo "✓ frontend/.env.local"
    fi
    
    # Herd links
    if [ -d "backend" ]; then
        cd backend
        herd link api.$BASE_DOMAIN
        herd secure api.$BASE_DOMAIN
        echo "✓ https://api.$BASE_DOMAIN.test"
        cd ..
    fi
    
    herd proxy $BASE_DOMAIN http://localhost:$FRONTEND_PORT --secure
    echo "✓ https://$BASE_DOMAIN.test → localhost:$FRONTEND_PORT"
    
    echo ""
    echo "Config updated!"
    echo "  API:      https://api.$BASE_DOMAIN.test"
    echo "  Frontend: https://$BASE_DOMAIN.test (run: cd frontend && pnpm dev -p $FRONTEND_PORT)"
}

# ============================================================
# Force mode: only update config
# ============================================================
if [ "$FORCE_CONFIG" = true ]; then
    update_config
    exit 0
fi

# ============================================================
# Full setup
# ============================================================

# Step 1: Install dependencies
echo "Step 1: Install dependencies"
npm install
echo "✓ npm dependencies"

# Step 2: Create Laravel backend
echo "Step 2: Create backend"
if [ ! -d "backend" ]; then
    laravel new backend --no-interaction
    cd backend
    
    # Install API with Sanctum
    php artisan install:api --no-interaction
    
    # Install SSO Client package (from local)
    echo "Installing SSO Client (local)..."
    composer config repositories.omnify-client-laravel-sso path ../../packages/omnify-client-laravel-sso
    composer config --no-plugins allow-plugins.omnifyjp/omnify-client-laravel-sso true
    composer require omnifyjp/omnify-client-laravel-sso:@dev lcobucci/jwt --no-interaction
    
    # Remove frontend stuff
    rm -rf resources/js resources/css public/build
    rm -f vite.config.js package.json package-lock.json postcss.config.js tailwind.config.js
    rm -rf node_modules
    
    # Configure from stubs
    cp "$STUBS_DIR/cors.php.stub" config/cors.php
    echo "✓ CORS configured"
    
    cp "$STUBS_DIR/bootstrap-app.php.stub" bootstrap/app.php
    echo "✓ Middleware configured"
    
    cp "$STUBS_DIR/User.php.stub" app/Models/User.php
    echo "✓ User model configured"
else
    cd backend
fi

# Step 3: Setup backend environment
echo ""
echo "Step 3: Setup environment"
render_stub "$STUBS_DIR/backend.env.stub" "" > .env

php artisan key:generate --force

# Publish SSO config
php artisan vendor:publish --tag=sso-client-config --force 2>/dev/null || true
echo "✓ Environment configured"

# Step 4: Link backend to Herd
herd link api.$BASE_DOMAIN
herd secure api.$BASE_DOMAIN
echo "✓ https://api.$BASE_DOMAIN.test"

# Step 5: Create Next.js frontend
echo ""
echo "Step 4: Create frontend"
cd ..
if [ ! -d "frontend" ]; then
    npx --yes create-next-app@latest frontend \
        --typescript \
        --tailwind \
        --eslint \
        --app \
        --src-dir \
        --import-alias "@/*" \
        --turbopack \
        --use-pnpm \
        --yes
    
    # Create .env.local from stub
    render_stub "$STUBS_DIR/frontend.env.stub" > frontend/.env.local
    
    # Install local React packages
    cd frontend
    pnpm add ../../packages/omnify-client-react ../../packages/omnify-client-react-sso
    cd ..
fi
echo "✓ frontend"

# Step 6: Proxy frontend
herd proxy $BASE_DOMAIN http://localhost:$FRONTEND_PORT --secure
echo "✓ https://$BASE_DOMAIN.test → localhost:$FRONTEND_PORT"

echo ""
echo "Done!"
echo "  API:      https://api.$BASE_DOMAIN.test"
echo "  Frontend: https://$BASE_DOMAIN.test (run: cd frontend && pnpm dev -p $FRONTEND_PORT)"
