#!/bin/bash
set -e

echo "Stopping local Selenium Grid..."
docker-compose down

echo "✓ Selenium Grid stopped"
