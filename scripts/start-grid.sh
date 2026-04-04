#!/bin/bash
set -e

echo "Starting local Selenium Grid..."

# Detect architecture
ARCH=$(uname -m)
IS_ARM64=false
if [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    IS_ARM64=true
fi

# Check if running on ARM64
if [[ "$IS_ARM64" == "true" ]]; then
    echo ""
    echo "⚠️  ARM64 architecture detected!"
    echo ""
    echo "Selenium Grid uses x86_64 images which require emulation on ARM64."
    echo ""
    
    # Check if Docker can run x86_64 images
    if ! docker run --rm --platform linux/amd64 alpine:latest uname -m &>/dev/null; then
        echo "❌ ERROR: Cannot run x86_64 images!"
        echo ""
        echo "For macOS (Apple Silicon):"
        echo "  1. Open Docker Desktop → Settings → General"
        echo "  2. Check 'Use Rosetta for x86/AMD64 emulation on Apple Silicon'"
        echo "  3. Click 'Apply & Restart'"
        echo ""
        echo "For Linux (ARM64):"
        echo "  1. Install QEMU: sudo apt-get install -y qemu-user-static"
        echo "  2. Enable binfmt: sudo docker run --rm --privileged multiarch/qemu-user-static --reset -p yes"
        echo ""
        echo "See SELENIUM-GRID-SETUP.md for more details."
        exit 1
    fi
    
    echo "✓ Basic x86_64 emulation is available"
    echo ""
    echo "Note: If containers fail to start, ensure Rosetta/QEMU is properly configured."
    echo "      See SELENIUM-GRID-SETUP.md for troubleshooting."
    echo ""
fi

# Start the grid
docker-compose up -d selenium-hub chrome firefox

echo ""
echo "Waiting for Selenium Grid to be ready..."
echo "(This may take 30-60 seconds for nodes to register)"
echo ""

# Wait longer for ARM64 systems
MAX_ATTEMPTS=60
if [[ "$IS_ARM64" == "true" ]]; then
    MAX_ATTEMPTS=120
    echo "Note: ARM64 emulation may be slower. Waiting up to 2 minutes..."
fi

ATTEMPTS=0
until curl -s http://localhost:4444/wd/hub/status 2>/dev/null | grep -q '"ready": true'; do
    ATTEMPTS=$((ATTEMPTS + 1))
    
    if [[ $ATTEMPTS -ge $MAX_ATTEMPTS ]]; then
        echo ""
        echo "❌ ERROR: Selenium Grid failed to become ready within $MAX_ATTEMPTS seconds"
        echo ""
        echo "Checking node logs..."
        echo "---"
        docker logs selenium-node-chrome 2>&1 | tail -20 || true
        echo "---"
        docker logs selenium-node-firefox 2>&1 | tail -20 || true
        echo "---"
        echo ""
        echo "Try stopping and starting again:"
        echo "  ./scripts/stop-grid.sh"
        echo "  ./scripts/start-grid.sh"
        echo ""
        exit 1
    fi
    
    sleep 2
    echo -n "."
done

echo ""
echo ""
echo "✅ Selenium Grid is ready!"
echo ""
echo "  Hub URL:     http://localhost:4444/wd/hub"
echo "  Chrome VNC:  http://localhost:7900 (password: secret)"
echo ""

# Show architecture info
if [[ "$IS_ARM64" == "true" ]]; then
    echo "  Running via: x86_64 emulation (Rosetta/QEMU)"
    echo ""
fi

# Check registered nodes
NODES=$(curl -s http://localhost:4444/wd/hub/status 2>/dev/null | grep -o '"nodes":\[' -A 50 | grep -c '"uri"' || echo "0")
echo "  Nodes:       $NODES registered"
echo ""
