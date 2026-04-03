#!/bin/bash
set -Eeuo pipefail

# Batch Verification Script for All Examples
# Uses each project's configured webdriver (Selenium or Playwright) to verify Storybook

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
VERIFY_SCRIPT="$SCRIPT_DIR/verify-storybook.sh"

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

# Find all example projects
find_projects() {
    for dir in "$REPO_ROOT"/*/; do
        if [[ -f "$dir/package.json" ]] && [[ -f "$dir/creevey.config.mjs" ]]; then
            basename "$dir"
        fi
    done
}

# Detect webdriver type
detect_webdriver() {
    local project="$1"
    local config_file="$REPO_ROOT/$project/creevey.config.mjs"

    if grep -q "PlaywrightWebdriver" "$config_file" 2>/dev/null; then
        echo "playwright"
    else
        echo "selenium"
    fi
}

# Check if project has webdriver dependencies installed
check_project_deps() {
    local project="$1"
    local project_dir="$REPO_ROOT/$project"
    local webdriver="$2"
    local missing_deps=()

    # Check for Yarn PnP (Plug'n'Play) - uses .pnp.cjs instead of node_modules
    if [[ -f "$project_dir/.pnp.cjs" ]]; then
        # Yarn PnP projects don't use node_modules
        return 0
    fi

    if [[ "$webdriver" == "playwright" ]]; then
        if [[ ! -f "$project_dir/node_modules/playwright/package.json" ]]; then
            missing_deps+=("playwright")
        fi
    else
        if [[ ! -f "$project_dir/node_modules/selenium-webdriver/package.json" ]]; then
            missing_deps+=("selenium-webdriver")
        fi
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "${missing_deps[*]}"
        return 1
    fi
    return 0
}

# Verify a single project
verify_project() {
    local project="$1"
    local port="$2"
    local webdriver="$3"

    log_section "Verifying: $project ($webdriver)"

    # Check dependencies
    local missing_deps
    if ! missing_deps=$(check_project_deps "$project" "$webdriver"); then
        log_error "Missing dependencies for $project: $missing_deps"
        log_info "Install with:"
        if [[ "$webdriver" == "playwright" ]]; then
            log_info "  cd $project && npm install -D playwright"
            log_info "  npx playwright install chromium"
        else
            log_info "  cd $project && npm install -D selenium-webdriver"
        fi
        return 1
    fi

    # Run verification
    if "$VERIFY_SCRIPT" -p "$port" "$REPO_ROOT/$project" 2>&1; then
        log_success "✓ $project: PASSED"
        return 0
    else
        log_error "✗ $project: FAILED"
        return 1
    fi
}

# Main execution
main() {
    log_section "STORYBOOK VERIFICATION FOR ALL EXAMPLES"
    echo "This script verifies Storybook for each example using its configured webdriver."
    echo ""

    # Find all projects
    local PROJECTS
    PROJECTS=$(find_projects | sort)

    if [[ -z "$PROJECTS" ]]; then
        log_error "No projects found to verify"
        exit 1
    fi

    local total_count=0
    local passed_count=0
    local failed_count=0
    local -a passed_projects=()
    local -a failed_projects=()
    local -a selenium_projects=()
    local -a playwright_projects=()

    # Categorize projects and count
    while IFS= read -r project; do
        [[ -z "$project" ]] && continue
        ((total_count++))
        
        local webdriver
        webdriver=$(detect_webdriver "$project")
        
        if [[ "$webdriver" == "playwright" ]]; then
            playwright_projects+=("$project")
        else
            selenium_projects+=("$project")
        fi
    done <<< "$PROJECTS"

    log_info "Found $total_count projects to verify:"
    log_info "  - ${#selenium_projects[@]} Selenium projects"
    log_info "  - ${#playwright_projects[@]} Playwright projects"
    echo ""

    # Process each project
    local port=6006
    while IFS= read -r project; do
        [[ -z "$project" ]] && continue

        local webdriver
        webdriver=$(detect_webdriver "$project")

        if verify_project "$project" "$port" "$webdriver"; then
            passed_projects+=("$project")
            ((passed_count++))
        else
            failed_projects+=("$project")
            ((failed_count++))
        fi

        # Increment port for next project
        ((port++))

        # Small delay between projects
        sleep 2
    done <<< "$PROJECTS"

    # Summary
    echo ""
    log_section "VERIFICATION SUMMARY"
    echo "Total: $total_count | Passed: $passed_count | Failed: $failed_count"
    echo ""

    if [[ ${#selenium_projects[@]} -gt 0 ]]; then
        echo "Selenium projects: ${#selenium_projects[@]}"
        for p in "${selenium_projects[@]}"; do
            if [[ " ${passed_projects[*]} " =~ " $p " ]]; then
                echo "  ✓ $p"
            else
                echo "  ✗ $p"
            fi
        done
    fi

    if [[ ${#playwright_projects[@]} -gt 0 ]]; then
        echo ""
        echo "Playwright projects: ${#playwright_projects[@]}"
        for p in "${playwright_projects[@]}"; do
            if [[ " ${passed_projects[*]} " =~ " $p " ]]; then
                echo "  ✓ $p"
            else
                echo "  ✗ $p"
            fi
        done
    fi

    if [[ $failed_count -gt 0 ]]; then
        echo ""
        log_error "Failed projects ($failed_count):"
        for p in "${failed_projects[@]}"; do
            echo "  ✗ $p"
        done
        exit 1
    fi

    echo ""
    log_success "All projects verified successfully!"
}

main "$@"
