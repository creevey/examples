#!/bin/bash
set -Eeuo pipefail

# Storybook Verification Script
# Builds Storybook and verifies it using the project's configured webdriver
# 
# Requirements:
# - Selenium projects: selenium-webdriver must be installed
# - Playwright projects: playwright must be installed

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"

# Configuration
STORYBOOK_PORT=${STORYBOOK_PORT:-6006}
SERVER_PID=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."

    if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        log_info "Stopping static server (PID: $SERVER_PID)..."
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}

# Set trap for cleanup
trap cleanup EXIT SIGINT SIGTERM

# Usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [PROJECT_DIR]

Builds Storybook and verifies it using the project's configured webdriver.

Arguments:
    PROJECT_DIR     Path to the example project directory (default: current directory)

Options:
    -h, --help      Show this help message
    -p, --port      Port for the static server (default: 6006)

Examples:
    $0                                    # Verify current directory
    $0 esm-vite-sb9                       # Verify specific project
    $0 -p 6010 esm-vite-sb9               # Use specific port

Webdriver Requirements:
    Selenium projects:    npm install -D selenium-webdriver
    Playwright projects:  npm install -D playwright
                          npx playwright install chromium
EOF
    exit "${1:-0}"
}

# Parse arguments
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage 0
            ;;
        -p|--port)
            STORYBOOK_PORT="$2"
            shift 2
            ;;
        -*)
            log_error "Unknown option: $1"
            usage 1
            ;;
        *)
            PROJECT_DIR="$1"
            shift
            ;;
    esac
done

# Determine project directory
if [[ -z "$PROJECT_DIR" ]]; then
    PROJECT_DIR="$(pwd)"
else
    # Handle relative paths
    if [[ ! "$PROJECT_DIR" = /* ]]; then
        PROJECT_DIR="$(pwd)/$PROJECT_DIR"
    fi
fi

# Validate project directory
if [[ ! -d "$PROJECT_DIR" ]]; then
    log_error "Project directory does not exist: $PROJECT_DIR"
    exit 1
fi

# Check for package.json
if [[ ! -f "$PROJECT_DIR/package.json" ]]; then
    log_error "No package.json found in project directory"
    exit 1
fi

PROJECT_NAME=$(basename "$PROJECT_DIR")
log_info "Verifying project: $PROJECT_NAME"
log_info "Project directory: $PROJECT_DIR"

# Detect package manager
detect_package_manager() {
    local dir="$1"

    if [[ -f "$dir/bun.lockb" ]] || [[ -f "$dir/bun.lock" ]]; then
        echo "bun"
    elif [[ -f "$dir/.yarnrc.yml" ]] || [[ -f "$dir/yarn.lock" ]]; then
        echo "yarn"
    elif [[ -f "$dir/pnpm-workspace.yaml" ]] || [[ -f "$dir/pnpm-lock.yaml" ]]; then
        echo "pnpm"
    else
        echo "npm"
    fi
}

PACKAGE_MANAGER=$(detect_package_manager "$PROJECT_DIR")
log_info "Detected package manager: $PACKAGE_MANAGER"

# Detect webdriver type from creevey.config.mjs
detect_webdriver_type() {
    local config_file="$PROJECT_DIR/creevey.config.mjs"

    if [[ ! -f "$config_file" ]]; then
        log_error "No creevey.config.mjs found"
        exit 1
    fi

    if grep -q "PlaywrightWebdriver" "$config_file"; then
        echo "playwright"
    else
        echo "selenium"
    fi
}

WEBDRIVER_TYPE=$(detect_webdriver_type)
log_info "Detected webdriver type: $WEBDRIVER_TYPE"

# Check webdriver dependencies
check_webdriver_deps() {
    if [[ "$WEBDRIVER_TYPE" == "playwright" ]]; then
        # Check for playwright or playwright-core
        if [[ ! -f "$PROJECT_DIR/node_modules/playwright/package.json" ]] && \
           [[ ! -f "$PROJECT_DIR/node_modules/playwright-core/package.json" ]]; then
            log_error "Playwright is not installed in this project"
            log_error "Install with: cd $PROJECT_NAME && npm install -D playwright"
            log_error "Then install browsers: npx playwright install chromium"
            exit 1
        fi
        
        # Check if browsers are installed (playwright-core contains the browsers)
        if [[ ! -d "$PROJECT_DIR/node_modules/playwright-core" ]]; then
            log_error "Playwright browsers may not be installed"
            log_error "Run: npx playwright install chromium"
            exit 1
        fi
    else
        # Check for Yarn PnP (Plug'n'Play) - uses .pnp.cjs instead of node_modules
        if [[ -f "$PROJECT_DIR/.pnp.cjs" ]]; then
            log_info "Yarn PnP detected, skipping node_modules check"
        elif [[ ! -f "$PROJECT_DIR/node_modules/selenium-webdriver/package.json" ]]; then
            log_error "selenium-webdriver is not installed in this project"
            log_error "Install with: cd $PROJECT_NAME && npm install -D selenium-webdriver"
            exit 1
        fi
    fi
}

# Run command with detected package manager
run_pm() {
    local cmd="$1"
    shift

    case "$PACKAGE_MANAGER" in
        npm)
            npm run "$cmd" -- "$@"
            ;;
        pnpm)
            pnpm run "$cmd" -- "$@"
            ;;
        yarn)
            yarn "$cmd" "$@"
            ;;
        bun)
            bun run "$cmd" "$@"
            ;;
    esac
}

# Install dependencies
install_dependencies() {
    if [[ -d "$PROJECT_DIR/node_modules" ]]; then
        log_info "Dependencies already installed, skipping..."
        return 0
    fi

    log_info "Installing dependencies..."

    cd "$PROJECT_DIR"

    case "$PACKAGE_MANAGER" in
        npm)
            npm install
            ;;
        pnpm)
            pnpm install
            ;;
        yarn)
            yarn install
            ;;
        bun)
            bun install
            ;;
    esac
}

# Build Storybook
build_storybook() {
    log_info "Building Storybook..."
    cd "$PROJECT_DIR"
    run_pm build-storybook
    log_success "Storybook built successfully"
}

# Start static server
start_server() {
    log_info "Starting static server on port $STORYBOOK_PORT..."
    cd "$PROJECT_DIR"

    # Check if port is already in use
    if lsof -Pi :"$STORYBOOK_PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
        log_warn "Port $STORYBOOK_PORT is already in use, killing existing process..."
        lsof -ti :"$STORYBOOK_PORT" | xargs kill -9 2>/dev/null || true
        sleep 2
    fi

    # Start http-server in background
    npx http-server ./storybook-static -p "$STORYBOOK_PORT" -s &
    SERVER_PID=$!

    # Wait for server to be ready
    local attempts=0
    local max_attempts=30

    while [[ $attempts -lt $max_attempts ]]; do
        if curl -s http://localhost:"$STORYBOOK_PORT" >/dev/null 2>&1; then
            log_success "Server is ready at http://localhost:$STORYBOOK_PORT"
            return 0
        fi

        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            log_error "Server process died unexpectedly"
            exit 1
        fi

        attempts=$((attempts + 1))
        sleep 1
    done

    log_error "Server failed to start within 30 seconds"
    exit 1
}

# Verify Storybook with Selenium
verify_with_selenium() {
    log_info "Verifying Storybook with Selenium WebDriver..."
    
    local verify_script="$SCRIPT_DIR/verify-storybook-selenium.mjs"
    
    if [[ ! -f "$verify_script" ]]; then
        log_error "Selenium verification script not found: $verify_script"
        exit 1
    fi

    export STORYBOOK_PORT="$STORYBOOK_PORT"
    export STORYBOOK_URL="http://localhost:$STORYBOOK_PORT"

    cd "$PROJECT_DIR"
    if node "$verify_script" 2>&1; then
        log_success "Selenium verification passed!"
        return 0
    else
        log_error "Selenium verification failed!"
        return 1
    fi
}

# Verify Storybook with Playwright
verify_with_playwright() {
    log_info "Verifying Storybook with Playwright..."
    
    local verify_script="$SCRIPT_DIR/verify-storybook-playwright.mjs"
    
    if [[ ! -f "$verify_script" ]]; then
        log_error "Playwright verification script not found: $verify_script"
        exit 1
    fi

    export STORYBOOK_PORT="$STORYBOOK_PORT"
    export STORYBOOK_URL="http://localhost:$STORYBOOK_PORT"

    cd "$PROJECT_DIR"
    if node "$verify_script" 2>&1; then
        log_success "Playwright verification passed!"
        return 0
    else
        log_error "Playwright verification failed!"
        return 1
    fi
}

# Verify Storybook based on webdriver type
verify_storybook() {
    if [[ "$WEBDRIVER_TYPE" == "playwright" ]]; then
        verify_with_playwright
    else
        verify_with_selenium
    fi
}

# Main execution
main() {
    log_info "Starting Storybook verification for $PROJECT_NAME"
    log_info "Webdriver type: $WEBDRIVER_TYPE"

    # Check webdriver dependencies
    check_webdriver_deps

    # Install dependencies
    install_dependencies

    # Build Storybook
    build_storybook

    # Start static server
    start_server

    # Verify with appropriate webdriver
    verify_storybook

    log_success "✓ All checks passed for $PROJECT_NAME!"
}

main "$@"
