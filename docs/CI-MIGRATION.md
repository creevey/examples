# CI/CD Migration: GitLab → GitHub Actions

## Overview

This document describes the migration from GitLab CI to GitHub Actions for Creevey screenshot testing.

## Migration Status

| Feature | GitLab CI | GitHub Actions | Status |
|---------|-----------|----------------|--------|
| Selenium Grid | ✅ | ✅ | Migrated |
| Playwright Docker | ✅ | ✅ | Migrated |
| Bun Runtime | ✅ | ✅ | Migrated |
| Multiple package managers | ✅ | ✅ | Migrated |
| Test artifacts | ✅ | ✅ | Migrated |
| PR comments | ❌ | ✅ | New feature |
| Manual workflow trigger | ❌ | ✅ | New feature |

## Workflow Structure

```
.github/workflows/
├── selenium-template.yml    # Reusable Selenium workflow
├── creevey-selenium.yml     # Selenium Grid test matrix
├── creevey-playwright.yml   # Playwright Docker tests
├── creevey-bun.yml          # Bun runtime tests
├── creevey-tests.yml        # Unified test runner
├── junit-reporter-ci.yml    # Dedicated JUnit reporter validation
└── test-results.yml         # PR comment automation
```

## Key Differences

### GitLab CI vs GitHub Actions

| GitLab CI | GitHub Actions |
|-----------|----------------|
| `services:` | `services:` (similar) |
| `image:` | `container:` |
| `artifacts:` | `actions/upload-artifact` |
| `only:` / `except:` | `on:` with conditional `if:` |
| `extends:` / YAML anchors | Reusable workflows (`uses:`) |
| `parallel:` | `strategy: matrix:` |

### Services Configuration

**GitLab CI:**
```yaml
services:
  - name: selenium/hub:4.18.1-20240220
    alias: selenium-hub
```

**GitHub Actions:**
```yaml
services:
  selenium-hub:
    image: selenium/hub:4.18.1-20240220
    ports:
      - 4444:4444
```

## Running Tests

### Automatic Triggers
- Push to `main` or `master`
- Pull requests to `main` or `master`

### Manual Trigger
Go to **Actions** → **Creevey Screenshot Tests** → **Run workflow**

Select test type:
- `all` - Run all test suites
- `selenium` - Run only Selenium Grid tests
- `playwright` - Run only Playwright Docker tests
- `bun` - Run only Bun runtime tests

## Artifacts

Test reports are saved as artifacts for 7 days with the naming pattern:
```
creevey-report-{fixture-name}
```

JUnit reporter validation additionally uploads scenario-specific XML and report artifacts:
```
junit-xml-{driver}-{scenario}
junit-report-{driver}-{scenario}
```

Access artifacts from:
- Workflow run summary page
- PR comments (if enabled)

## Troubleshooting

### Selenium Grid Connection Issues
Ensure the Selenium services are healthy before running tests:
```yaml
options: >-
  --health-cmd "curl -f http://localhost:4444/wd/hub/status || exit 1"
  --health-interval 10s
```

### Playwright Browser Installation
Playwright Docker images include browsers. No separate installation needed.

### Package Manager Detection
The workflows auto-detect package managers based on file presence:
- `pnpm-workspace.yaml` → pnpm
- `.yarnrc.yml` → Yarn
- Otherwise → npm
