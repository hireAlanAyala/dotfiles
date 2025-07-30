#!/bin/bash
set -euo pipefail

# Docker Test Runner for VPS Provisioning Scripts
# This script builds and runs the Docker test environment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="vps-config-test"
CONTAINER_NAME="vps-test-$(date +%s)"

echo "=== VPS Configuration Docker Test Runner ==="

# Function to cleanup on exit
cleanup() {
    echo "🧹 Cleaning up..."
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
}
trap cleanup EXIT

# Build the Docker image
echo "🔨 Building Docker test image..."
cd "$SCRIPT_DIR"
docker build -t "$IMAGE_NAME" .

# Run the container interactively
echo "🚀 Starting test container: $CONTAINER_NAME"
echo "📂 Mounting current config directory as read-only"

docker run -it --rm \
    --name "$CONTAINER_NAME" \
    --mount type=bind,source="$(dirname "$SCRIPT_DIR")",target=/mnt/config,readonly \
    "$IMAGE_NAME" bash -c '
echo "=== Docker Test Environment Ready (Unified Config) ==="
echo "📁 Config directory mounted at: /mnt/config"
echo "🔧 Available unified script:"
echo "   - /tmp/unified-setup.sh (handles all provisioning)"
echo ""
echo "🧪 Quick test commands:"
echo "   # Test complete setup (recommended)"
echo "   /tmp/unified-setup.sh"
echo ""
echo "   # Test with GPG key generation"
echo "   GENERATE_TEST_KEY=true /tmp/unified-setup.sh"
echo ""
echo "   # Test Home Manager setup"
echo "   cp -r /mnt/config/home-manager ~/.config/"
echo "   cd ~/.config/home-manager && nix build"
echo ""
echo "🔍 Environment detection:"
echo "   source /tmp/config.env && echo \"Detected: \$DETECTED_ENV\""
echo ""
echo "💡 The unified script handles packages, user setup, GPG, and everything else!"
echo "💡 Type \"exit\" to leave the container"
echo ""
exec bash
'