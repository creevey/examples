#!/bin/bash
set -Eeuo pipefail

# Batch Creevey Test Runner for All Examples
# Builds Storybook, serves it, and runs Creevey for each example project
#
# This script handles:
# - Auto-starting Selenium Grid when needed (for Selenium-based projects)
# - Running Creevey tests for each project sequentially with unique ports
# - Creating/updating baseline screenshots
# - Stopping infrastructure when complete

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
RUN_SCRIPT="$SCRIPT_DIR/run-creevey.sh"

# Configuration
PORT=6006
GRID_STARTED_BY_SCRIPT=false
SKIP_START_GRID=false
SKIP_STOP_GRID=false
KEEP_GRID_RUNNING=false

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

log_section() {
    echo ""
    echo "========================================"
    echo "$*"
    echo "========================================"
}

# Cleanup function - stop grid if we started it
cleanup() {
    local exit_code=$?
    
    if [[ "$GRID_STARTED_BY_SCRIPT" == "true" ]] && [[ "$KEEP_GRID_RUNNING" == "false" ]]; then
        log_info "Stopping Selenium Grid (started by this script)..."
        if "$SCRIPT_DIR/stop-grid.sh" 2>/dev/null; then
            log_success "Selenium Grid stopped"
        else
            log_warn "Failed to stop Selenium Grid (may already be stopped)"
        fi
    elif [[ "$GRID_STARTED_BY_SCRIPT" == "true" ]] && [[ "$KEEP_GRID_RUNNING" == "true" ]]; then
        log_info "Keeping Selenium Grid running (use --stop-grid to stop it later)"
    fi
    
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT SIGINT SIGTERM

# Usage information
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Runs Creevey tests for all example projects sequentially.

Options:
    -h, --help              Show this help message
    -p, --port PORT         Port for Storybook server (default: 6006)
    --start-grid            Always start Selenium Grid before running tests
    --skip-start-grid       Skip starting Selenium Grid (fail if not running)
    --keep-grid-running     Keep grid running after tests complete
    --stop-grid             Stop Selenium Grid after tests (default behavior)
    --selenium-only         Run only Selenium-based projects
    --playwright-only       Run only Playwright-based projects
    --project PROJECT       Run specific project only

Examples:
    $0                                  # Run all tests (auto-manage grid)
    $0 --start-grid                     # Force start grid before tests
    $0 --skip-start-grid                # Fail if grid not running
    $0 --keep-grid-running              # Leave grid running after tests
    $0 --selenium-only                  # Run only Selenium projects
    $0 --playwright-only                # Run only Playwright projects
    $0 --project esm-vite-sb9           # Run specific project

Infrastructure:
    Selenium Grid:    Required for 10 projects (all except 3 Docker Playwright)
    Docker:           Required for 3 Playwright Docker projects

Note: Creevey 0.10.35+ removed --update flag. Use 'creevey report' to approve images.
EOF
    exit "${1:-0}"
}

# Check if Selenium Grid is running
check_grid_running() {
    local grid_url="http://localhost:4444/wd/hub"
    
    if curl -s "$grid_url/status" 2>/dev/null | grep -q '"ready": true' || \
       curl -s "$grid_url" 2>/dev/null | grep -q "Selenium" || \
       curl -s "$grid_url/status" 2>/dev/null | grep -q "Grid" ; then
        return 0
    fi
    return 1
}

# Check if Docker is available
check_docker() {
    if command -v docker &>/dev/null && docker info &>/dev/null; then
        return 0
    fi
    return 1
}

# Find all example projects
find_projects() {
    local projects=()
    
    for dir in "$REPO_ROOT"/*/; do
        local project_name
        project_name=$(basename "$dir")
        
        # Skip non-project directories
        [[ "$project_name" == "scripts" ]] && continue
        [[ "$project_name" == ".git" ]] && continue
        [[ "$project_name" == ".github" ]] && continue
        [[ "$project_name" == "docs" ]] && continue
        
        # Check if it's a valid project
        if [[ -f "$dir/package.json" ]] && [[ -f "$dir/creevey.config.mjs" ]]; then
            projects+=("$project_name")
        fi
    done
    
    printf '%s\n' "${projects[@]}" | sort
}

# Detect webdriver type from creevey.config.mjs
detect_webdriver_type() {
    local project="$1"
    local config_file="$REPO_ROOT/$project/creevey.config.mjs"
    
    if [[ ! -f "$config_file" ]]; then
        echo "unknown"
        return
    fi
    
    if grep -q "PlaywrightWebdriver" "$config_file" 2>/dev/null; then
        if grep -q "useDocker.*true" "$config_file" 2>/dev/null; then
            echo "playwright-docker"
        else
            echo "playwright-grid"
        fi
    else
        echo "selenium"
    fi
}

# Check if project needs Selenium Grid
needs_selenium_grid() {
    local project="$1"
    local webdriver
    webdriver=$(detect_webdriver_type "$project")
    
    [[ "$webdriver" == "selenium" ]] || [[ "$webdriver" == "playwright-grid" ]]
}

# Check if project needs Docker
needs_docker() {
    local project="$1"
    local webdriver
    webdriver=$(detect_webdriver_type "$project")
    
    [[ "$webdriver" == "playwright-docker" ]]
}

# Count projects needing infrastructure
count_infrastructure_needs() {
    local projects=("$@")
    local grid_count=0
    local docker_count=0
    
    for project in "${projects[@]}"; do
        if needs_selenium_grid "$project"; then
            ((grid_count++))
        fi
        if needs_docker "$project"; then
            ((docker_count++))
        fi
    done
    
    echo "$grid_count $docker_count"
}

# Check project dependencies
check_project_deps() {
    local project="$1"
    local project_dir="$REPO_ROOT/$project"
    local missing_deps=()
    
    # Check for Yarn PnP
    if [[ -f "$project_dir/.pnp.cjs" ]]; then
        return 0
    fi
    
    # Check if node_modules exists
    if [[ ! -d "$project_dir/node_modules" ]]; then
        missing_deps+=("node_modules")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "${missing_deps[*]}"
        return 1
    fi
    return 0
}

# Run Creevey for a single project
run_project() {
    local project="$1"
    local webdriver="$2"
    
    log_section "Running: $project ($webdriver)"
    
    # Check dependencies
    local missing_deps
    if ! missing_deps=$(check_project_deps "$project"); then
        log_warn "Missing dependencies for $project: $missing_deps"
        log_info "Installing dependencies..."
        cd "$REPO_ROOT/$project"
        
        # Auto-detect and install
        if [[ -f "bun.lockb" ]] || [[ -f "bun.lock" ]]; then
            bun install
        elif [[ -f ".yarnrc.yml" ]] || [[ -f "yarn.lock" ]]; then
            yarn install
        elif [[ -f "pnpm-workspace.yaml" ]] || [[ -f "pnpm-lock.yaml" ]]; then
            pnpm install
        else
            npm install
        fi
    fi
    
    # Build args for run-creevey.sh
    local args=(-p "$PORT")
    
    # Run Creevey
    cd "$REPO_ROOT"
    if "$RUN_SCRIPT" "${args[@]}" "$REPO_ROOT/$project" 2>&1; then
        log_success "✓ $project: PASSED"
        return 0
    else
        log_error "✗ $project: FAILED"
        return 1
    fi
}

# Parse arguments
PROJECTS_TO_RUN=()
SELENIUM_ONLY=false
PLAYWRIGHT_ONLY=false
SPECIFIC_PROJECT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage 0
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        --start-grid)
            SKIP_START_GRID=false
            shift
            ;;
        --skip-start-grid)
            SKIP_START_GRID=true
            shift
            ;;
        --keep-grid-running)
            KEEP_GRID_RUNNING=true
            shift
            ;;
        --stop-grid)
            KEEP_GRID_RUNNING=false
            shift
            ;;
        --selenium-only)
            SELENIUM_ONLY=true
            shift
            ;;
        --playwright-only)
            PLAYWRIGHT_ONLY=true
            shift
            ;;
        --project)
            SPECIFIC_PROJECT="$2"
            shift 2
            ;;
        -*)
            log_error "Unknown option: $1"
            usage 1
            ;;
        *)
            log_error "Unexpected argument: $1"
            usage 1
            ;;
    esac
done

# Validate options
if [[ "$SELENIUM_ONLY" == "true" ]] && [[ "$PLAYWRIGHT_ONLY" == "true" ]]; then
    log_error "Cannot use both --selenium-only and --playwright-only"
    exit 1
fi

# Main execution
main() {
    log_section "CREEVEY BATCH TEST RUNNER"
    log_info "Mode: TEST RUN"
    
    # Find all projects
    local ALL_PROJECTS
    ALL_PROJECTS=($(find_projects))
    
    if [[ ${#ALL_PROJECTS[@]} -eq 0 ]]; then
        log_error "No projects found to run"
        exit 1
    fi
    
    # Filter projects based on options
    local PROJECTS=()
    
    if [[ -n "$SPECIFIC_PROJECT" ]]; then
        # Run specific project
        local found=false
        for p in "${ALL_PROJECTS[@]}"; do
            if [[ "$p" == "$SPECIFIC_PROJECT" ]]; then
                PROJECTS+=("$p")
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            log_error "Project not found: $SPECIFIC_PROJECT"
            log_info "Available projects:"
            for p in "${ALL_PROJECTS[@]}"; do
                echo "  - $p"
            done
            exit 1
        fi
    elif [[ "$SELENIUM_ONLY" == "true" ]]; then
        for p in "${ALL_PROJECTS[@]}"; do
            if needs_selenium_grid "$p"; then
                PROJECTS+=("$p")
            fi
        done
    elif [[ "$PLAYWRIGHT_ONLY" == "true" ]]; then
        for p in "${ALL_PROJECTS[@]}"; do
            if needs_docker "$p"; then
                PROJECTS+=("$p")
            fi
        done
    else
        PROJECTS=("${ALL_PROJECTS[@]}")
    fi
    
    local total_count=${#PROJECTS[@]}
    
    if [[ $total_count -eq 0 ]]; then
        log_error "No projects match the criteria"
        exit 1
    fi
    
    # Count infrastructure needs
    local grid_needed_count docker_needed_count
    read -r grid_needed_count docker_needed_count < <(count_infrastructure_needs "${PROJECTS[@]}")
    
    log_info "Found $total_count project(s) to run:"
    log_info "  - $grid_needed_count need Selenium Grid"
    log_info "  - $docker_needed_count need Docker (Playwright)"
    echo ""
    
    for p in "${PROJECTS[@]}"; do
        local wd
        wd=$(detect_webdriver_type "$p")
        echo "  - $p ($wd)"
    done
    echo ""
    
    # Check Docker if needed
    if [[ $docker_needed_count -gt 0 ]]; then
        log_info "Checking Docker..."
        if check_docker; then
            log_success "Docker is available"
        else
            log_error "Docker is required for $docker_needed_count project(s) but is not available"
            log_error "Please install and start Docker"
            exit 1
        fi
        echo ""
    fi
    
    # Handle Selenium Grid
    if [[ $grid_needed_count -gt 0 ]]; then
        log_info "Checking Selenium Grid..."
        
        if check_grid_running; then
            log_success "Selenium Grid is already running"
        elif [[ "$SKIP_START_GRID" == "true" ]]; then
            log_error "Selenium Grid is required but not running"
            log_error "Start it with: ./scripts/start-grid.sh"
            exit 1
        else
            log_info "Selenium Grid not running, starting it..."
            if "$SCRIPT_DIR/start-grid.sh"; then
                GRID_STARTED_BY_SCRIPT=true
                log_success "Selenium Grid started successfully"
            else
                log_error "Failed to start Selenium Grid"
                exit 1
            fi
        fi
        echo ""
    fi
    
    # Run tests for each project
    # All projects use the same port (cleanup handled by run-creevey.sh)
    local passed_count=0
    local failed_count=0
    local -a passed_projects=()
    local -a failed_projects=()
    
    for project in "${PROJECTS[@]}"; do
        local webdriver
        webdriver=$(detect_webdriver_type "$project")
        
        if run_project "$project" "$webdriver"; then
            passed_projects+=("$project")
            ((passed_count++))
        else
            failed_projects+=("$project")
            ((failed_count++))
        fi
        
        
        # Small delay between projects
        if [[ "$project" != "${PROJECTS[${#PROJECTS[@]}-1]}" ]]; then
            log_info "Waiting 2 seconds before next project..."
            sleep 2
        fi
    done
    
    # Summary
    log_section "TEST SUMMARY"
    echo "Total: $total_count | Passed: $passed_count | Failed: $failed_count"
    echo ""
    
    if [[ $passed_count -gt 0 ]]; then
        log_success "Passed projects ($passed_count):"
        for p in "${passed_projects[@]}"; do
            echo "  ✓ $p"
        done
        echo ""
    fi
    
    if [[ $failed_count -gt 0 ]]; then
        log_error "Failed projects ($failed_count):"
        for p in "${failed_projects[@]}"; do
            echo "  ✗ $p"
        done
        echo ""
    fi
    
    # Final status
    if [[ $failed_count -eq 0 ]]; then
        log_success "All tests completed successfully!"
        if [[ "$UPDATE_MODE" == "true" ]]; then
            log_info "Baseline images have been updated."
        fi
        exit 0
    else
        log_error "Some tests failed!"
        exit 1
    fi
}

main "$@"
