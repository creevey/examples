# Migrate Creevey CI from GitLab to GitHub Actions

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate Creevey screenshot testing CI/CD from GitLab CI to GitHub Actions while maintaining all existing test configurations and functionality.

**Architecture:** Create GitHub Actions workflows using matrix strategies for parallel testing across different project configurations (Selenium/Playwright, various package managers, Node versions). Use GitHub Actions services for Selenium Grid, reusable workflow patterns for DRY configuration, and artifact uploads for test reports.

**Tech Stack:** GitHub Actions, Selenium Grid, Playwright Docker, Node.js 20/22, Bun, npm/yarn/pnpm

---

## Project Overview

The repository contains **13 test projects** organized into 3 categories:

| Category | Count | Projects | Base Image |
|----------|-------|----------|------------|
| Selenium Grid | 9 | cjs-webpack-sb8, cjs-vite-sb8, esm-webpack-sb8, esm-vite-sb8, esm-vite-sb9, esm-vite-sb9-yarn-pnp, esm-vite-sb9-pnpm, esm-vite-sb9-playwright, esm-vite-sb10 | node:20-alpine |
| Playwright Docker | 2 | playwright-esm-vite-sb9, playwright-esm-vite-sb10-react19 | mcr.microsoft.com/playwright:v1.50.0-jammy |
| Bun Runtime | 1 | playwright-esm-vite-sb10-bun | oven/bun:1.2 |

### Key Configuration Differences

| Project | Node Version | Package Manager | Notes |
|---------|--------------|-----------------|-------|
| esm-vite-sb9-yarn-pnp | 20 | Yarn PnP | Uses `.yarnrc.yml` |
| esm-vite-sb9-pnpm | 20 | pnpm | Uses `pnpm-workspace.yaml` |
| esm-vite-sb9-playwright | 20 (full) | npm | Requires full Node image |
| esm-vite-sb10 | 22 | npm | SB10 requires Node 20.19+ or 22.12+ |
| playwright-esm-vite-sb9 | Playwright | npm | Docker-based browsers |
| playwright-esm-vite-sb10-bun | Bun 1.2 | bun | Bun runtime |
| playwright-esm-vite-sb10-react19 | Playwright | npm | React 19 + Playwright |

---

## Task 1: Create Directory Structure for GitHub Actions

**Files:**
- Create: `.github/workflows/`

**Step 1: Create workflow directory**

Run:
```bash
mkdir -p .github/workflows
```

**Step 2: Commit**

```bash
git add .github/
git commit -m "chore(ci): create GitHub Actions workflow directory"
```

---

## Task 2: Create Reusable Workflow for Selenium Tests

**Files:**
- Create: `.github/workflows/selenium-template.yml`

**Step 1: Write reusable workflow**

```yaml
name: Selenium Test Template

on:
  workflow_call:
    inputs:
      fixture:
        required: true
        type: string
        description: 'Project directory name'
      node-version:
        required: false
        type: string
        default: '20'
        description: 'Node.js version'
      use-full-node:
        required: false
        type: boolean
        default: false
        description: 'Use full node image instead of alpine'

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      selenium-hub:
        image: selenium/hub:4.18.1-20240220
        ports:
          - 4444:4444
        options: >-
          --health-cmd "curl -f http://localhost:4444/wd/hub/status || exit 1"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      selenium-node-chrome:
        image: selenium/node-chrome:4.18.1-20240220
        env:
          SE_EVENT_BUS_HOST: selenium-hub
          SE_EVENT_BUS_PUBLISH_PORT: 4442
          SE_EVENT_BUS_SUBSCRIBE_PORT: 4443
          HUB_HOST: selenium-hub
          HUB_PORT: 4444
        options: >-
          --health-cmd "curl -f http://localhost:5555/status || exit 1"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        if: ${{ !inputs.use-full-node }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}

      - name: Setup pnpm
        if: ${{ hashFiles(format('{0}/pnpm-workspace.yaml', inputs.fixture)) != '' }}
        uses: pnpm/action-setup@v2
        with:
          version: 9

      - name: Detect and install dependencies
        working-directory: ${{ inputs.fixture }}
        run: |
          if [ -f "pnpm-workspace.yaml" ]; then
            pnpm install
          elif [ -f ".yarnrc.yml" ]; then
            corepack enable
            yarn install
          else
            npm install
          fi

      - name: Build Storybook
        working-directory: ${{ inputs.fixture }}
        run: |
          if [ -f "pnpm-workspace.yaml" ]; then
            pnpm run build-storybook
          elif [ -f ".yarnrc.yml" ]; then
            yarn build-storybook
          else
            npm run build-storybook
          fi

      - name: Start Storybook server
        working-directory: ${{ inputs.fixture }}
        run: |
          npx http-server ./storybook-static -p 6006 -s &
          npx wait-on http://localhost:6006 --timeout 30000

      - name: Run Creevey tests
        working-directory: ${{ inputs.fixture }}
        env:
          SELENIUM_GRID_URL: http://localhost:4444/wd/hub
        run: |
          if [ -f "pnpm-workspace.yaml" ]; then
            pnpm exec creevey --debug
          elif [ -f ".yarnrc.yml" ]; then
            yarn creevey --debug
          else
            npx creevey --debug
          fi

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: creevey-report-${{ inputs.fixture }}
          path: ${{ inputs.fixture }}/report
          retention-days: 7
```

**Step 2: Commit**

```bash
git add .github/workflows/selenium-template.yml
git commit -m "ci(github-actions): add reusable Selenium test workflow template"
```

---

## Task 3: Create Main Selenium Grid Workflow with Matrix

**Files:**
- Create: `.github/workflows/creevey-selenium.yml`

**Step 1: Write main Selenium workflow**

```yaml
name: Creevey Screenshot Tests - Selenium Grid

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:

jobs:
  # Standard Selenium projects (Node 20, alpine)
  selenium-tests:
    strategy:
      fail-fast: false
      matrix:
        fixture:
          - cjs-webpack-sb8
          - cjs-vite-sb8
          - esm-webpack-sb8
          - esm-vite-sb8
          - esm-vite-sb9
        include:
          - fixture: esm-vite-sb9-yarn-pnp
            node-version: '20'
          - fixture: esm-vite-sb9-pnpm
            node-version: '20'
    uses: ./.github/workflows/selenium-template.yml
    with:
      fixture: ${{ matrix.fixture }}
      node-version: '20'

  # Playwright variant (requires full Node image)
  selenium-playwright:
    uses: ./.github/workflows/selenium-template.yml
    with:
      fixture: esm-vite-sb9-playwright
      node-version: '20'
      use-full-node: true

  # Storybook 10 projects (requires Node 22)
  selenium-sb10:
    uses: ./.github/workflows/selenium-template.yml
    with:
      fixture: esm-vite-sb10
      node-version: '22'
```

**Step 2: Commit**

```bash
git add .github/workflows/creevey-selenium.yml
git commit -m "ci(github-actions): add Selenium Grid test workflow with matrix strategy"
```

---

## Task 4: Create Playwright Docker Workflow

**Files:**
- Create: `.github/workflows/creevey-playwright.yml`

**Step 1: Write Playwright workflow**

```yaml
name: Creevey Screenshot Tests - Playwright Docker

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:

jobs:
  playwright-tests:
    strategy:
      fail-fast: false
      matrix:
        include:
          - fixture: playwright-esm-vite-sb9
          - fixture: playwright-esm-vite-sb10-react19

    runs-on: ubuntu-latest
    container:
      image: mcr.microsoft.com/playwright:v1.50.0-jammy
      options: --ipc=host

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install dependencies
        working-directory: ${{ matrix.fixture }}
        run: npm install

      - name: Build Storybook
        working-directory: ${{ matrix.fixture }}
        run: npm run build-storybook

      - name: Start Storybook server
        working-directory: ${{ matrix.fixture }}
        run: |
          npx http-server ./storybook-static -p 6006 -s &
          npx wait-on http://localhost:6006 --timeout 30000

      - name: Run Creevey tests
        working-directory: ${{ matrix.fixture }}
        run: npx creevey --debug

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: creevey-report-${{ matrix.fixture }}
          path: ${{ matrix.fixture }}/report
          retention-days: 7
```

**Step 2: Commit**

```bash
git add .github/workflows/creevey-playwright.yml
git commit -m "ci(github-actions): add Playwright Docker test workflow"
```

---

## Task 5: Create Bun Runtime Workflow

**Files:**
- Create: `.github/workflows/creevey-bun.yml`

**Step 1: Write Bun workflow**

```yaml
name: Creevey Screenshot Tests - Bun Runtime

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:

jobs:
  bun-tests:
    strategy:
      fail-fast: false
      matrix:
        include:
          - fixture: playwright-esm-vite-sb10-bun

    runs-on: ubuntu-latest
    container:
      image: oven/bun:1.2
      options: --ipc=host

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install dependencies
        working-directory: ${{ matrix.fixture }}
        run: bun install

      - name: Build Storybook
        working-directory: ${{ matrix.fixture }}
        run: bun run build-storybook

      - name: Start Storybook server
        working-directory: ${{ matrix.fixture }}
        run: |
          bunx http-server ./storybook-static -p 6006 -s &
          bunx wait-on http://localhost:6006 --timeout 30000

      - name: Run Creevey tests
        working-directory: ${{ matrix.fixture }}
        run: bunx creevey --debug

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: creevey-report-${{ matrix.fixture }}
          path: ${{ matrix.fixture }}/report
          retention-days: 7
```

**Step 2: Commit**

```bash
git add .github/workflows/creevey-bun.yml
git commit -m "ci(github-actions): add Bun runtime test workflow"
```

---

## Task 6: Create Unified Test Workflow

**Files:**
- Create: `.github/workflows/creevey-tests.yml`

**Step 1: Write unified workflow**

```yaml
name: Creevey Screenshot Tests

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:
    inputs:
      test-type:
        description: 'Test type to run'
        required: true
        default: 'all'
        type: choice
        options:
          - all
          - selenium
          - playwright
          - bun

jobs:
  # Determine which tests to run
  selenium:
    if: ${{ github.event.inputs.test-type == 'all' || github.event.inputs.test-type == 'selenium' || github.event_name != 'workflow_dispatch' }}
    uses: ./.github/workflows/creevey-selenium.yml
    secrets: inherit

  playwright:
    if: ${{ github.event.inputs.test-type == 'all' || github.event.inputs.test-type == 'playwright' || github.event_name != 'workflow_dispatch' }}
    uses: ./.github/workflows/creevey-playwright.yml
    secrets: inherit

  bun:
    if: ${{ github.event.inputs.test-type == 'all' || github.event.inputs.test-type == 'bun' || github.event_name != 'workflow_dispatch' }}
    uses: ./.github/workflows/creevey-bun.yml
    secrets: inherit

  # Summary job that depends on all test jobs
  test-summary:
    needs: [selenium, playwright, bun]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Test Summary
        run: |
          echo "## Creevey Test Results" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Test Type | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|-----------|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| Selenium Grid | ${{ needs.selenium.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Playwright Docker | ${{ needs.playwright.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Bun Runtime | ${{ needs.bun.result }} |" >> $GITHUB_STEP_SUMMARY
```

**Step 2: Commit**

```bash
git add .github/workflows/creevey-tests.yml
git commit -m "ci(github-actions): add unified test workflow with summary"
```

---

## Task 7: Add Workflow for PR Comments with Test Results

**Files:**
- Create: `.github/workflows/test-results.yml`

**Step 1: Write PR comment workflow**

```yaml
name: Post Test Results

on:
  workflow_run:
    workflows: ["Creevey Screenshot Tests"]
    types:
      - completed

jobs:
  post-results:
    runs-on: ubuntu-latest
    if: github.event.workflow_run.event == 'pull_request'
    steps:
      - name: Download artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts
          pattern: creevey-report-*
          merge-multiple: false

      - name: Post PR comment
        uses: actions/github-script@v7
        with:
          script: |
            const { data: pullRequests } = await github.rest.repos.listPullRequestsAssociatedWithCommit({
              owner: context.repo.owner,
              repo: context.repo.repo,
              commit_sha: context.payload.workflow_run.head_sha
            });
            
            if (pullRequests.length === 0) {
              console.log('No PR found for this commit');
              return;
            }
            
            const prNumber = pullRequests[0].number;
            const workflowRun = context.payload.workflow_run;
            const conclusion = workflowRun.conclusion;
            const status = conclusion === 'success' ? '✅ PASSED' : '❌ FAILED';
            
            const body = `## Creevey Screenshot Test Results ${status}
            
            **Workflow:** [${workflowRun.name} #${workflowRun.run_number}](${workflowRun.html_url})
            **Commit:** ${workflowRun.head_sha.substring(0, 7)}
            **Conclusion:** ${conclusion}
            
            ${conclusion === 'failure' ? '⚠️ Please check the artifacts for screenshot diffs.' : 'All screenshot tests passed!'}
            `;
            
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: prNumber,
              body: body
            });
```

**Step 2: Commit**

```bash
git add .github/workflows/test-results.yml
git commit -m "ci(github-actions): add PR comment workflow for test results"
```

---

## Task 8: Create CI Migration Documentation

**Files:**
- Create: `docs/CI-MIGRATION.md`

**Step 1: Write migration documentation**

```markdown
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
```

**Step 2: Commit**

```bash
git add docs/CI-MIGRATION.md
git commit -m "docs: add CI migration documentation"
```

---

## Task 9: Update Root README with GitHub Actions Badges

**Files:**
- Modify: `README.md` (add badges section)

**Step 1: Read README to find badge insertion point**

```bash
head -50 README.md
```

**Step 2: Add GitHub Actions badges**

Find the location after the title/header and add:

```markdown
## CI Status

[![Creevey Screenshot Tests](https://github.com/{owner}/{repo}/actions/workflows/creevey-tests.yml/badge.svg)](https://github.com/{owner}/{repo}/actions/workflows/creevey-tests.yml)
[![Selenium Grid Tests](https://github.com/{owner}/{repo}/actions/workflows/creevey-selenium.yml/badge.svg)](https://github.com/{owner}/{repo}/actions/workflows/creevey-selenium.yml)
[![Playwright Docker Tests](https://github.com/{owner}/{repo}/actions/workflows/creevey-playwright.yml/badge.svg)](https://github.com/{owner}/{repo}/actions/workflows/creevey-playwright.yml)

> **Note:** Replace `{owner}/{repo}` with your actual GitHub repository path.
```

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs(readme): add GitHub Actions CI badges"
```

---

## Task 10: Test the GitHub Actions Workflows

**Files:**
- Push workflows to GitHub
- Monitor workflow runs

**Step 1: Push to GitHub**

```bash
git push origin main
```

**Step 2: Verify workflows appear**

1. Go to GitHub repository
2. Click **Actions** tab
3. Verify workflows are listed:
   - Creevey Screenshot Tests
   - Creevey Screenshot Tests - Selenium Grid
   - Creevey Screenshot Tests - Playwright Docker
   - Creevey Screenshot Tests - Bun Runtime

**Step 3: Trigger test run**

Option A: Create a test PR
```bash
git checkout -b test/github-actions
# Make a small change
git commit -m "test: trigger GitHub Actions"
git push origin test/github-actions
# Create PR on GitHub
```

Option B: Manual trigger
1. Go to Actions → Creevey Screenshot Tests
2. Click "Run workflow"
3. Select `all` tests
4. Click "Run workflow"

**Step 4: Monitor results**

Check each workflow for:
- ✅ Services start successfully
- ✅ Dependencies install
- ✅ Storybook builds
- ✅ Server starts
- ✅ Creevey tests run
- ✅ Artifacts uploaded

**Step 5: Verify artifacts**

1. Click on completed workflow run
2. Scroll to "Artifacts" section
3. Download `creevey-report-*` artifacts
4. Verify reports contain expected data

---

## Task 11: Remove or Archive GitLab CI Configuration

**Files:**
- Rename: `.gitlab-ci.yml` → `.gitlab-ci.yml.bak`

**Step 1: Backup GitLab CI file**

```bash
mv .gitlab-ci.yml .gitlab-ci.yml.bak
git add .gitlab-ci.yml.bak
git commit -m "chore(ci): backup GitLab CI configuration"
```

**Step 2: Remove active GitLab CI**

```bash
git rm .gitlab-ci.yml
git commit -m "chore(ci): remove GitLab CI configuration - migrated to GitHub Actions"
```

---

## Task 12: Final Verification and Documentation Update

**Step 1: Create final verification checklist**

```markdown
## Migration Verification Checklist

### Workflows
- [ ] All 13 test projects have corresponding GitHub Actions jobs
- [ ] Selenium Grid services start correctly
- [ ] Playwright Docker container works
- [ ] Bun runtime container works
- [ ] Matrix strategy covers all project variants

### Test Execution
- [ ] Tests run on push to main
- [ ] Tests run on PR to main
- [ ] Manual trigger works
- [ ] All package managers work (npm, yarn, pnpm, bun)
- [ ] Different Node versions work (20, 22)

### Artifacts & Reporting
- [ ] Test reports upload successfully
- [ ] Artifacts are downloadable
- [ ] PR comments appear (if enabled)
- [ ] Workflow summary shows status

### Documentation
- [ ] README has CI badges
- [ ] CI-MIGRATION.md is accurate
- [ ] All workflow files are documented
```

**Step 2: Run final test**

Trigger a full test run and verify all items pass.

**Step 3: Update documentation**

Add any discovered issues or workarounds to `docs/CI-MIGRATION.md`.

**Step 4: Final commit**

```bash
git add .
git commit -m "ci(github-actions): complete migration from GitLab CI

- Migrated 13 test projects to GitHub Actions
- Created reusable workflow templates
- Added support for all package managers (npm, yarn, pnpm, bun)
- Configured Selenium Grid services
- Added Playwright Docker and Bun runtime workflows
- Implemented PR comment automation
- Added comprehensive documentation"
```

---

## Rollback Plan

If issues arise:

1. **Quick rollback to GitLab CI:**
   ```bash
   git revert HEAD~{n}  # Revert migration commits
   git mv .gitlab-ci.yml.bak .gitlab-ci.yml
   git commit -m "ci: rollback to GitLab CI"
   ```

2. **Disable GitHub Actions temporarily:**
   - Rename `.github/workflows/*.yml` to `*.yml.disabled`

3. **Run tests locally:**
   ```bash
   cd $FIXTURE
   npm run build-storybook
   npx http-server ./storybook-static -p 6006 -s &
   npx creevey
   ```

---

## Implementation Order Summary

1. ✅ Task 1: Create directory structure
2. ✅ Task 2: Create reusable Selenium template
3. ✅ Task 3: Create Selenium matrix workflow
4. ✅ Task 4: Create Playwright workflow
5. ✅ Task 5: Create Bun workflow
6. ✅ Task 6: Create unified test workflow
7. ✅ Task 7: Add PR comment workflow
8. ✅ Task 8: Create migration documentation
9. ✅ Task 9: Update README badges
10. ✅ Task 10: Test workflows
11. ✅ Task 11: Archive GitLab CI
12. ✅ Task 12: Final verification

**Estimated Time:** 2-3 hours for implementation + testing

**Risk Level:** Low-Medium (parallel testing strategy recommended)
