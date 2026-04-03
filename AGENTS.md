# AGENTS.md - Coding Guidelines for Creevey Examples

This repository contains demo configurations for Creevey visual regression testing with Storybook.

## Repository Structure

- Multiple example projects in subdirectories (e.g., `esm-vite-sb9/`, `playwright-esm-vite-sb10/`)
- Each project is self-contained with its own `package.json` and dependencies
- CI workflows in `.github/workflows/`

## Development Environment Setup (fnm + Corepack)

This repository uses **fnm** for Node.js version management and **corepack** for automatic package manager switching.

### Prerequisites

```bash
# Install fnm (Fast Node Manager)
curl -fsSL https://fnm.vercel.app/install | bash

# Install Node versions
fnm install 20
fnm install 22

# Enable corepack
corepack enable
```

### Shell Configuration

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# fnm auto-switch on cd
eval "$(fnm env --use-on-cd)"

# Enable corepack on directory change (zsh)
_fnm_cd_hook() {
  if [[ -f .nvmrc ]] && command -v corepack &> /dev/null; then
    corepack enable 2>/dev/null || true
  fi
}
add-zsh-hook chpwd _fnm_cd_hook
```

### Usage

Simply `cd` into any project - Node and package manager auto-switch:

```bash
cd esm-vite-sb9       # Auto: Node 20 + npm
cd ../esm-vite-sb9-pnpm  # Auto: Node 20 + pnpm
cd ../esm-vite-sb9-yarn-pnp  # Auto: Node 20 + yarn
cd ../playwright-esm-vite-sb10-bun  # Auto: Node 22 + bun
```

### Project Configuration

Each project includes:
- `.nvmrc` - Node version for fnm
- `packageManager` in `package.json` - Package manager for corepack
- `engines.node` - Node version requirement

See [`.fnm-setup.md`](.fnm-setup.md) for detailed configuration.

## Build/Test Commands

### Per-Project Commands (run from project subdirectory)

```bash
# Install dependencies
cd <project-dir>
npm install        # or: pnpm install, yarn install, bun install

# Build Storybook
npm run build-storybook

# Start Storybook dev server
npm run storybook

# Run Creevey tests
npm run creevey           # Run all tests
npm run creevey:ui        # Run with UI mode
npm run creevey:update    # Update baselines
```

### Selenium Grid (Local Development)

```bash
# Start Selenium Grid (requires Docker)
./scripts/start-grid.sh   # Starts grid at http://localhost:4444/wd/hub
./scripts/stop-grid.sh    # Stop grid

# Run tests with grid
cd esm-vite-sb9
npm run build-storybook
npx http-server ./storybook-static -p 6006 -s &
npx creevey
```

### CI Workflows (GitHub Actions)

```bash
# All tests
gh workflow run creevey-tests.yml

# Specific test types
gh workflow run creevey-selenium.yml    # Selenium Grid tests (9 projects)
gh workflow run creevey-playwright.yml  # Playwright Docker tests (2 projects)
gh workflow run creevey-bun.yml         # Bun runtime tests (1 project)
```

## Code Style Guidelines

### JavaScript/JSX

- **Module system**: Use `type: "module"` for ESM (preferred), omit for CJS
- **Imports**: Use ES module imports for ESM projects:
  ```javascript
  import React from "react";
  import { Button } from "./Button";
  import "./button.css";
  ```
- **Exports**: Named exports for components: `export const Button = ...`
- **Quotes**: Prefer double quotes for strings
- **Semicolons**: Use semicolons
- **Indentation**: 2 spaces
- **Line endings**: LF

### File Naming

- Components: PascalCase (e.g., `Button.jsx`)
- Config files: kebab-case (e.g., `creevey.config.mjs`)
- Stories: PascalCase with `.stories.js` suffix (e.g., `Button.stories.js`)
- Styles: kebab-case (e.g., `button.css`)

### Storybook Patterns

```javascript
// stories/Button.stories.js
import { Button } from "./Button";

export default {
  title: "Example/Button",  // Storybook title path
  component: Button,
  parameters: {
    layout: "centered",
  },
  tags: ["autodocs"],
  argTypes: {
    backgroundColor: { control: "color" },
  },
};

// Story exports
export const Primary = {
  args: {
    primary: true,
    label: "Button",
  },
};
```

### Creevey Configuration

```javascript
// creevey.config.mjs
import path from "path";
import { fileURLToPath } from "url";
import { PlaywrightWebdriver } from "creevey/playwright";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {import('creevey').CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  useDocker: true,              // For Playwright
  webdriver: PlaywrightWebdriver,
  // OR: gridUrl: "http://localhost:4444/wd/hub", // For Selenium Grid
  browsers: {
    chromium: {
      browserName: "chromium",
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
```

### CSS Conventions

- BEM-style naming: `.storybook-button`, `.storybook-button--primary`
- Component-scoped styles in same directory as component

### Package Managers

Projects use different package managers based on purpose:
- **npm**: Default for most projects
- **pnpm**: `esm-vite-sb9-pnpm/` (check `pnpm-workspace.yaml`)
- **Yarn PnP**: `esm-vite-sb9-yarn-pnp/` (check `.yarnrc.yml`)
- **Bun**: `playwright-esm-vite-sb10-bun/`

### Environment Requirements

| Project Type | Node Version |
|--------------|-------------|
| SB8, SB9 projects | Node 20+ |
| SB10 projects | Node 22+ |
| Bun projects | Bun runtime |

## Error Handling

- CI scripts use `set -e` for bash error handling
- GitHub Actions use `fail-fast: false` in matrices to run all variants
- Test artifacts are uploaded even on failure (`if: always()`)

## Git Workflow

- Default branch: `master`
- CI triggers on push/PR to `master`
- Workflows support manual dispatch with test type selection
