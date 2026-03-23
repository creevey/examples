#!/bin/bash
set -e

echo "Starting local Selenium Grid..."
docker-compose up -d selenium-hub chrome firefox

echo "Waiting for Selenium Grid to be ready..."
until curl -s http://localhost:4444/wd/hub/status | grep -q '"ready": true'; do
  sleep 2
done

echo ""
echo "✓ Selenium Grid is ready!"
echo "  Hub URL: http://localhost:4444/wd/hub"
echo "  Chrome VNC: http://localhost:7900 (password: secret)"
echo ""
