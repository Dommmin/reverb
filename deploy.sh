#!/bin/bash

set -e
set -o pipefail

APP_USER="deployer"
APP_GROUP="www-data"
APP_BASE="/home/$APP_USER/laravel"
RELEASES_DIR="$APP_BASE/releases"
SHARED_DIR="$APP_BASE/shared"
CURRENT_LINK="$APP_BASE/current"
NOW=$(date +%Y-%m-%d-%H%M%S)-$(openssl rand -hex 3)
RELEASE_DIR="$RELEASES_DIR/$NOW"
ARCHIVE_NAME="release.tar.gz"

echo "▶️ Create directories..."
mkdir -p "$RELEASES_DIR" "$SHARED_DIR/storage" "$SHARED_DIR/bootstrap_cache"

mkdir -p "$SHARED_DIR/storage/framework/"{views,cache,sessions}
mkdir -p "$SHARED_DIR/storage/logs"

echo "▶️ Unpacking release..."
mkdir -p "$RELEASE_DIR"
tar -xzf "$APP_BASE/$ARCHIVE_NAME" -C "$RELEASE_DIR"
rm -f "$APP_BASE/$ARCHIVE_NAME"

echo "▶️ Setting up symlinks..."
rm -rf "$RELEASE_DIR/storage"
ln -s "$SHARED_DIR/storage" "$RELEASE_DIR/storage"

rm -rf "$RELEASE_DIR/bootstrap/cache"
ln -s "$SHARED_DIR/bootstrap_cache" "$RELEASE_DIR/bootstrap/cache"

ln -sf "$SHARED_DIR/.env" "$RELEASE_DIR/.env"
ln -sf "$SHARED_DIR/database/database.sqlite" "$RELEASE_DIR/database/database.sqlite"
ln -sf "$SHARED_DIR/public/sitemap.xml" "$RELEASE_DIR/public/sitemap.xml"

echo "▶️ Optimizing application..."
cd "$RELEASE_DIR"
php artisan optimize:clear

# Reset opcache if available
if command -v opcache_reset &> /dev/null; then
    echo "▶️ Resetting OPcache..."
    php -r "opcache_reset();" || true
fi

php artisan optimize
php artisan storage:link

echo "▶️ Running database migrations..."
php artisan migrate --force

# Update symlink first
echo "▶️ Updating current symlink..."
ln -sfn "$RELEASE_DIR" "$CURRENT_LINK"

echo "▶️ Restarting PHP-FPM to apply new code..."
if sudo systemctl restart php8.3-fpm; then
    echo "✅ PHP-FPM restarted successfully"
else
    echo "❌ Failed to restart PHP-FPM!"
    exit 1
fi

echo "▶️ Cleaning old releases (keeping 5 latest)..."
cd "$RELEASES_DIR"
ls -dt */ | tail -n +6 | xargs -r rm -rf

echo "▶️ Checking health status..."
curl http://localhost/health

echo "✅ Deployment successful: $NOW"
exit 0
