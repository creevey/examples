# Remove Enterprise Dependencies and Restructure Example Projects

> **Goal:** Remove all enterprise-specific configurations and restructure example projects to cover: CJS/ESM, Webpack/Vite, Storybook 8/9/10, package managers (npm/yarn/pnpm/yarn-pnp), runtimes (node/bun), and React versions.

**Architecture:** 
- Replace enterprise npm registry with public npm registry in all projects
- Replace enterprise docker images with public Docker Hub images in GitLab CI
- Restructure projects into clear naming convention: `{module}-{builder}-sb{version}-{variant}`
- Use local Docker-based Selenium Grid for all Selenium-based projects
- Keep Playwright projects using Docker-based browsers
- Add pnpm and React 19 variants

**Tech Stack:** TypeScript, Creevey, Storybook, Yarn, pnpm, Docker, Selenium Grid, Playwright, Bun

---

## Project Restructuring Overview

### Current Projects (8) → New Projects (12)

| Current Project | Action | New Project(s) |
|----------------|--------|----------------|
| `esm/` | **Migrate** | `esm-vite-sb9/` (base ESM+Vite+SB9) |
| `playwright-docker/` | **Migrate** | `playwright-esm-vite-sb9/`, `playwright-esm-vite-sb10-bun/` |
| `playwright-grid/` | **Delete** | Merged into playwright variants |
| `vite/` | **Delete** | SB7 no longer supported |
| `vite-sb8/` | **Migrate** | `esm-vite-sb8/` |
| `webpack/` | **Delete** | SB7 no longer supported |
| `webpack-sb8/` | **Migrate** | `cjs-webpack-sb8/` |
| `yarn-pnp/` | **Migrate** | `esm-vite-sb9-yarn-pnp/` |

### New Project Structure (12 projects)

#### Selenium Grid Projects (9 projects)

**CJS + SB8 (2 projects):**
1. `cjs-webpack-sb8/` - CJS + Webpack 5 + Storybook 8 + Selenium
2. `cjs-vite-sb8/` - CJS + Vite + Storybook 8 + Selenium

**ESM + SB8 (2 projects):**
3. `esm-webpack-sb8/` - ESM + Webpack 5 + Storybook 8 + Selenium
4. `esm-vite-sb8/` - ESM + Vite + Storybook 8 + Selenium

**ESM + Vite + SB9 variants (4 projects):**
5. `esm-vite-sb9/` - ESM + Vite + Storybook 9 + Selenium (base)
6. `esm-vite-sb9-yarn-pnp/` - ESM + Vite + Storybook 9 + Yarn PnP + Selenium
7. `esm-vite-sb9-pnpm/` - ESM + Vite + Storybook 9 + pnpm + Selenium
8. `esm-vite-sb9-playwright/` - ESM + Vite + Storybook 9 + Playwright + Selenium Grid

**ESM + Vite + SB10 (1 project):**
9. `esm-vite-sb10/` - ESM + Vite + Storybook 10 + Selenium

#### Playwright Docker Projects (3 projects)

10. `playwright-esm-vite-sb9/` - ESM + Vite + Storybook 9 + Playwright Docker
11. `playwright-esm-vite-sb10-bun/` - ESM + Vite + Storybook 10 + Bun + Playwright Docker
12. `playwright-esm-vite-sb10-react19/` - ESM + Vite + Storybook 10 + React 19 + Playwright Docker

---

## Task 1: Delete Old Projects

**Files:**
- Delete: `esm/` directory
- Delete: `playwright-docker/` directory
- Delete: `playwright-grid/` directory
- Delete: `vite/` directory
- Delete: `vite-sb8/` directory
- Delete: `webpack/` directory
- Delete: `webpack-sb8/` directory
- Delete: `yarn-pnp/` directory

**Step 1: Delete all old project directories**

```bash
cd /Users/ki/Projects/creevey/sb7-creevey
rm -rf esm playwright-docker playwright-grid vite vite-sb8 webpack webpack-sb8 yarn-pnp
```

**Step 2: Verify deletion**

```bash
ls -la
# Should only show: .git, .gitignore, .gitlab-ci.yml, .vscode, docs, README.md, and any root files
```

**Step 3: Commit**

```bash
git add -A
git commit -m "chore: remove old example projects (SB7, legacy structure)"
```

---

## Task 2: Create Local Selenium Grid Infrastructure

**Files:**
- Create: `docker-compose.yml` (at repo root)
- Create: `scripts/start-grid.sh`
- Create: `scripts/stop-grid.sh`
- Modify: `.gitignore`

**Step 1: Create docker-compose.yml for local Selenium Grid**

```yaml
version: "3.8"
services:
  selenium-hub:
    image: selenium/hub:4.18.1-20240220
    container_name: selenium-hub
    ports:
      - "4444:4444"
    environment:
      - GRID_MAX_SESSION=16
      - GRID_TIMEOUT=30000
      - GRID_BROWSER_TIMEOUT=30000

  chrome:
    image: selenium/node-chrome:4.18.1-20240220
    shm_size: 2gb
    depends_on:
      - selenium-hub
    environment:
      - HUB_HOST=selenium-hub
      - HUB_PORT=4444
      - NODE_MAX_INSTANCES=4
      - NODE_MAX_SESSION=4
      - SCREEN_WIDTH=1920
      - SCREEN_HEIGHT=1080
      - VNC_NO_PASSWORD=1
    volumes:
      - /dev/shm:/dev/shm
    ports:
      - "7900:7900"  # VNC port for debugging

  firefox:
    image: selenium/node-firefox:4.18.1-20240220
    shm_size: 2gb
    depends_on:
      - selenium-hub
    environment:
      - HUB_HOST=selenium-hub
      - HUB_PORT=4444
      - NODE_MAX_INSTANCES=2
      - NODE_MAX_SESSION=2
      - SCREEN_WIDTH=1920
      - SCREEN_HEIGHT=1080
    volumes:
      - /dev/shm:/dev/shm
```

**Step 2: Create start-grid.sh script**

```bash
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
```

**Step 3: Create stop-grid.sh script**

```bash
#!/bin/bash
set -e

echo "Stopping local Selenium Grid..."
docker-compose down

echo "✓ Selenium Grid stopped"
```

**Step 4: Make scripts executable**

```bash
chmod +x scripts/start-grid.sh scripts/stop-grid.sh
```

**Step 5: Update .gitignore**

Add to `.gitignore`:
```
# Selenium Grid
.docker/
*.log
```

**Step 6: Commit**

```bash
git add docker-compose.yml scripts/start-grid.sh scripts/stop-grid.sh .gitignore
git commit -m "feat: add local Selenium Grid infrastructure with docker-compose"
```

---

## Task 3: Create CJS Projects

### Task 3.1: Create cjs-webpack-sb8 Project

**Files:**
- Create: `cjs-webpack-sb8/package.json`
- Create: `cjs-webpack-sb8/creevey.config.mjs`
- Create: `cjs-webpack-sb8/.storybook/main.js`
- Create: `cjs-webpack-sb8/.storybook/preview.js`
- Create: `cjs-webpack-sb8/stories/Button.jsx`
- Create: `cjs-webpack-sb8/stories/Button.stories.js`
- Create: `cjs-webpack-sb8/stories/button.css`

**Step 1: Create package.json**

```json
{
  "name": "creevey-cjs-webpack-sb8",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^8.6.0",
    "@storybook/addon-webpack5-compiler-swc": "^1.0.0",
    "@storybook/react": "^8.6.0",
    "@storybook/react-webpack5": "^8.6.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "selenium-webdriver": "^4.28.0",
    "storybook": "^8.6.0"
  }
}
```

**Step 2: Create creevey.config.mjs**

```javascript
import { CreeveyConfig } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  gridUrl: "http://localhost:4444/wd/hub",
  browsers: {
    chrome: {
      browserName: "chrome",
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
```

**Step 3: Create .storybook/main.js**

```javascript
/** @type { import('@storybook/react-webpack5').StorybookConfig } */
const config = {
  stories: ["../stories/**/*.stories.@(js|jsx|ts|tsx)"],
  addons: ["@storybook/addon-essentials"],
  framework: {
    name: "@storybook/react-webpack5",
    options: {},
  },
};

export default config;
```

**Step 4: Create .storybook/preview.js**

```javascript
/** @type { import('@storybook/react').Preview } */
const preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
  },
};

export default preview;
```

**Step 5: Create stories/Button.jsx**

```jsx
import React from "react";
import "./button.css";

export const Button = ({ primary, backgroundColor, size, label, ...props }) => {
  const mode = primary ? "storybook-button--primary" : "storybook-button--secondary";
  return (
    <button
      type="button"
      className={["storybook-button", `storybook-button--${size}`, mode].join(" ")}
      style={backgroundColor && { backgroundColor }}
      {...props}
    >
      {label}
    </button>
  );
};
```

**Step 6: Create stories/Button.stories.js**

```javascript
import { Button } from "./Button";

export default {
  title: "Example/Button",
  component: Button,
  parameters: {
    layout: "centered",
  },
  tags: ["autodocs"],
  argTypes: {
    backgroundColor: { control: "color" },
  },
};

export const Primary = {
  args: {
    primary: true,
    label: "Button",
  },
};

export const Secondary = {
  args: {
    label: "Button",
  },
};

export const Large = {
  args: {
    size: "large",
    label: "Button",
  },
};

export const Small = {
  args: {
    size: "small",
    label: "Button",
  },
};
```

**Step 7: Create stories/button.css**

```css
.storybook-button {
  font-family: "Nunito Sans", "Helvetica Neue", Helvetica, Arial, sans-serif;
  font-weight: 700;
  border: 0;
  border-radius: 3em;
  cursor: pointer;
  display: inline-block;
  line-height: 1;
}

.storybook-button--primary {
  color: white;
  background-color: #1ea7fd;
}

.storybook-button--secondary {
  color: #333;
  background-color: transparent;
  box-shadow: rgba(0, 0, 0, 0.15) 0px 0px 0px 1px inset;
}

.storybook-button--small {
  font-size: 12px;
  padding: 10px 16px;
}

.storybook-button--large {
  font-size: 16px;
  padding: 12px 24px;
}
```

**Step 8: Commit**

```bash
git add cjs-webpack-sb8/
git commit -m "feat: add cjs-webpack-sb8 example project"
```

---

### Task 3.2: Create cjs-vite-sb8 Project

**Files:**
- Create: `cjs-vite-sb8/package.json`
- Create: `cjs-vite-sb8/creevey.config.mjs`
- Create: `cjs-vite-sb8/.storybook/main.js`
- Create: `cjs-vite-sb8/.storybook/preview.js`
- Create: `cjs-vite-sb8/vite.config.js`
- Create: `cjs-vite-sb8/stories/` (same as cjs-webpack-sb8)

**Step 1: Create package.json**

```json
{
  "name": "creevey-cjs-vite-sb8",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^8.6.0",
    "@storybook/react": "^8.6.0",
    "@storybook/react-vite": "^8.6.0",
    "@vitejs/plugin-react": "^4.3.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "selenium-webdriver": "^4.28.0",
    "storybook": "^8.6.0",
    "vite": "^5.4.0"
  }
}
```

**Step 2: Create creevey.config.mjs**

```javascript
import { CreeveyConfig } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  gridUrl: "http://localhost:4444/wd/hub",
  browsers: {
    chrome: {
      browserName: "chrome",
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
```

**Step 3: Create .storybook/main.js**

```javascript
/** @type { import('@storybook/react-vite').StorybookConfig } */
const config = {
  stories: ["../stories/**/*.stories.@(js|jsx|ts|tsx)"],
  addons: ["@storybook/addon-essentials"],
  framework: {
    name: "@storybook/react-vite",
    options: {},
  },
};

export default config;
```

**Step 4: Create vite.config.js**

```javascript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
});
```

**Step 5: Copy stories from cjs-webpack-sb8**

```bash
cp -r cjs-webpack-sb8/stories cjs-vite-sb8/
```

**Step 6: Commit**

```bash
git add cjs-vite-sb8/
git commit -m "feat: add cjs-vite-sb8 example project"
```

---

## Task 4: Create ESM + SB8 Projects

### Task 4.1: Create esm-webpack-sb8 Project

**Files:**
- Create: `esm-webpack-sb8/package.json`
- Create: `esm-webpack-sb8/creevey.config.mjs`
- Create: `esm-webpack-sb8/.storybook/main.js`
- Create: `esm-webpack-sb8/.storybook/preview.js`
- Create: `esm-webpack-sb8/stories/` (same components)

**Step 1: Create package.json**

```json
{
  "name": "creevey-esm-webpack-sb8",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^8.6.0",
    "@storybook/addon-webpack5-compiler-swc": "^1.0.0",
    "@storybook/react": "^8.6.0",
    "@storybook/react-webpack5": "^8.6.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "selenium-webdriver": "^4.28.0",
    "storybook": "^8.6.0"
  }
}
```

**Step 2: Create creevey.config.mjs**

```javascript
import { CreeveyConfig } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  gridUrl: "http://localhost:4444/wd/hub",
  browsers: {
    chrome: {
      browserName: "chrome",
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
```

**Step 3: Copy stories from cjs-webpack-sb8**

```bash
cp -r cjs-webpack-sb8/stories esm-webpack-sb8/
```

**Step 4: Create .storybook/main.js**

```javascript
/** @type { import('@storybook/react-webpack5').StorybookConfig } */
const config = {
  stories: ["../stories/**/*.stories.@(js|jsx|ts|tsx)"],
  addons: ["@storybook/addon-essentials"],
  framework: {
    name: "@storybook/react-webpack5",
    options: {},
  },
};

export default config;
```

**Step 5: Create .storybook/preview.js**

```javascript
/** @type { import('@storybook/react').Preview } */
const preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
  },
};

export default preview;
```

**Step 6: Commit**

```bash
git add esm-webpack-sb8/
git commit -m "feat: add esm-webpack-sb8 example project"
```

---

### Task 4.2: Create esm-vite-sb8 Project

**Files:**
- Create: `esm-vite-sb8/package.json` with `"type": "module"`
- Create: `esm-vite-sb8/creevey.config.mjs`
- Create: `esm-vite-sb8/.storybook/main.js`
- Create: `esm-vite-sb8/vite.config.js`
- Create: `esm-vite-sb8/stories/` (copy from cjs-webpack-sb8)

**Step 1: Create package.json**

```json
{
  "name": "creevey-esm-vite-sb8",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^8.6.0",
    "@storybook/react": "^8.6.0",
    "@storybook/react-vite": "^8.6.0",
    "@vitejs/plugin-react": "^4.3.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "selenium-webdriver": "^4.28.0",
    "storybook": "^8.6.0",
    "vite": "^5.4.0"
  }
}
```

**Step 2: Create creevey.config.mjs**

```javascript
import { CreeveyConfig } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  gridUrl: "http://localhost:4444/wd/hub",
  browsers: {
    chrome: {
      browserName: "chrome",
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
```

**Step 3: Create .storybook/main.js**

```javascript
/** @type { import('@storybook/react-vite').StorybookConfig } */
const config = {
  stories: ["../stories/**/*.stories.@(js|jsx|ts|tsx)"],
  addons: ["@storybook/addon-essentials"],
  framework: {
    name: "@storybook/react-vite",
    options: {},
  },
};

export default config;
```

**Step 4: Create vite.config.js**

```javascript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
});
```

**Step 5: Copy stories**

```bash
cp -r cjs-webpack-sb8/stories esm-vite-sb8/
```

**Step 6: Commit**

```bash
git add esm-vite-sb8/
git commit -m "feat: add esm-vite-sb8 example project"
```

---

## Task 5: Create ESM + Vite + SB9 Projects

### Task 5.1: Create esm-vite-sb9 (Base)

**Files:**
- Create: `esm-vite-sb9/package.json` with SB 9.1.20
- Create: `esm-vite-sb9/creevey.config.mjs`
- Create: `esm-vite-sb9/.storybook/main.js`
- Create: `esm-vite-sb9/vite.config.js`
- Create: `esm-vite-sb9/stories/`

**Step 1: Create package.json**

```json
{
  "name": "creevey-esm-vite-sb9",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^9.1.20",
    "@storybook/react": "^9.1.20",
    "@storybook/react-vite": "^9.1.20",
    "@vitejs/plugin-react": "^4.3.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "selenium-webdriver": "^4.28.0",
    "storybook": "^9.1.20",
    "vite": "^5.4.0"
  }
}
```

**Step 2: Create creevey.config.mjs**

```javascript
import { CreeveyConfig } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  gridUrl: "http://localhost:4444/wd/hub",
  browsers: {
    chrome: {
      browserName: "chrome",
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
```

**Step 3: Create .storybook/main.js**

```javascript
/** @type { import('@storybook/react-vite').StorybookConfig } */
const config = {
  stories: ["../stories/**/*.stories.@(js|jsx|ts|tsx)"],
  addons: ["@storybook/addon-essentials"],
  framework: {
    name: "@storybook/react-vite",
    options: {},
  },
};

export default config;
```

**Step 4: Create vite.config.js**

```javascript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
});
```

**Step 5: Copy stories**

```bash
cp -r cjs-webpack-sb8/stories esm-vite-sb9/
```

**Step 6: Commit**

```bash
git add esm-vite-sb9/
git commit -m "feat: add esm-vite-sb9 base example project"
```

---

### Task 5.2: Create esm-vite-sb9-yarn-pnp

**Files:**
- Create: `esm-vite-sb9-yarn-pnp/package.json`
- Create: `esm-vite-sb9-yarn-pnp/.yarnrc.yml`
- Create: `esm-vite-sb9-yarn-pnp/creevey.config.mjs`
- Create: `esm-vite-sb9-yarn-pnp/.storybook/main.js`
- Create: `esm-vite-sb9-yarn-pnp/vite.config.js`
- Create: `esm-vite-sb9-yarn-pnp/stories/`

**Step 1: Create package.json**

```json
{
  "name": "creevey-esm-vite-sb9-yarn-pnp",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^9.1.20",
    "@storybook/react": "^9.1.20",
    "@storybook/react-vite": "^9.1.20",
    "@vitejs/plugin-react": "^4.3.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "selenium-webdriver": "^4.28.0",
    "storybook": "^9.1.20",
    "vite": "^5.4.0"
  },
  "packageManager": "yarn@4.6.0"
}
```

**Step 2: Create .yarnrc.yml**

```yaml
nodeLinker: pnp
pnpMode: strict
yarnPath: .yarn/releases/yarn-4.6.0.cjs
```

**Step 3: Copy config files from esm-vite-sb9**

```bash
cp esm-vite-sb9/creevey.config.mjs esm-vite-sb9-yarn-pnp/
cp esm-vite-sb9/.storybook/main.js esm-vite-sb9-yarn-pnp/.storybook/
cp esm-vite-sb9/vite.config.js esm-vite-sb9-yarn-pnp/
cp -r cjs-webpack-sb8/stories esm-vite-sb9-yarn-pnp/
```

**Step 4: Download Yarn 4.6.0**

```bash
mkdir -p esm-vite-sb9-yarn-pnp/.yarn/releases
curl -L -o esm-vite-sb9-yarn-pnp/.yarn/releases/yarn-4.6.0.cjs https://repo.yarnpkg.com/4.6.0/packages/yarnpkg-cli/bin/yarn.js
```

**Step 5: Commit**

```bash
git add esm-vite-sb9-yarn-pnp/
git commit -m "feat: add esm-vite-sb9-yarn-pnp example project"
```

---

### Task 5.3: Create esm-vite-sb9-pnpm

**Files:**
- Create: `esm-vite-sb9-pnpm/package.json`
- Create: `esm-vite-sb9-pnpm/pnpm-workspace.yaml`
- Create: `esm-vite-sb9-pnpm/creevey.config.mjs`
- Create: `esm-vite-sb9-pnpm/.storybook/main.js`
- Create: `esm-vite-sb9-pnpm/vite.config.js`
- Create: `esm-vite-sb9-pnpm/stories/`

**Step 1: Create package.json**

```json
{
  "name": "creevey-esm-vite-sb9-pnpm",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^9.1.20",
    "@storybook/react": "^9.1.20",
    "@storybook/react-vite": "^9.1.20",
    "@vitejs/plugin-react": "^4.3.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "selenium-webdriver": "^4.28.0",
    "storybook": "^9.1.20",
    "vite": "^5.4.0"
  },
  "packageManager": "pnpm@9.15.0"
}
```

**Step 2: Create pnpm-workspace.yaml**

```yaml
packages:
  - '.'
```

**Step 3: Copy config files**

```bash
cp esm-vite-sb9/creevey.config.mjs esm-vite-sb9-pnpm/
cp esm-vite-sb9/.storybook/main.js esm-vite-sb9-pnpm/.storybook/
cp esm-vite-sb9/vite.config.js esm-vite-sb9-pnpm/
cp -r cjs-webpack-sb8/stories esm-vite-sb9-pnpm/
```

**Step 4: Commit**

```bash
git add esm-vite-sb9-pnpm/
git commit -m "feat: add esm-vite-sb9-pnpm example project"
```

---

### Task 5.4: Create esm-vite-sb9-playwright

**Files:**
- Create: `esm-vite-sb9-playwright/package.json`
- Create: `esm-vite-sb9-playwright/creevey.config.mjs` (with PlaywrightWebdriver)
- Create: `esm-vite-sb9-playwright/.storybook/main.js`
- Create: `esm-vite-sb9-playwright/vite.config.js`
- Create: `esm-vite-sb9-playwright/stories/`

**Step 1: Create package.json**

```json
{
  "name": "creevey-esm-vite-sb9-playwright",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^9.1.20",
    "@storybook/react": "^9.1.20",
    "@storybook/react-vite": "^9.1.20",
    "@vitejs/plugin-react": "^4.3.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "playwright-core": "^1.50.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "storybook": "^9.1.20",
    "vite": "^5.4.0"
  }
}
```

**Step 2: Create creevey.config.mjs**

```javascript
import { CreeveyConfig, PlaywrightWebdriver } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  webdriver: PlaywrightWebdriver,
  // Uses Selenium Grid with Playwright WebDriver
  gridUrl: "http://localhost:4444/wd/hub",
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

**Step 3: Copy remaining files**

```bash
cp esm-vite-sb9/.storybook/main.js esm-vite-sb9-playwright/.storybook/
cp esm-vite-sb9/vite.config.js esm-vite-sb9-playwright/
cp -r cjs-webpack-sb8/stories esm-vite-sb9-playwright/
```

**Step 4: Commit**

```bash
git add esm-vite-sb9-playwright/
git commit -m "feat: add esm-vite-sb9-playwright example project"
```

---

## Task 6: Create ESM + Vite + SB10 Project

**Files:**
- Create: `esm-vite-sb10/package.json` with SB 10.3.1
- Create: `esm-vite-sb10/creevey.config.mjs`
- Create: `esm-vite-sb10/.storybook/main.js`
- Create: `esm-vite-sb10/vite.config.js`
- Create: `esm-vite-sb10/stories/`

**Step 1: Create package.json**

```json
{
  "name": "creevey-esm-vite-sb10",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^10.3.1",
    "@storybook/react": "^10.3.1",
    "@storybook/react-vite": "^10.3.1",
    "@vitejs/plugin-react": "^4.3.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "selenium-webdriver": "^4.28.0",
    "storybook": "^10.3.1",
    "vite": "^5.4.0 || ^6.0.0"
  },
  "engines": {
    "node": ">=20.19.0 || >=22.12.0"
  }
}
```

**Step 2: Create creevey.config.mjs**

```javascript
import { CreeveyConfig } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  gridUrl: "http://localhost:4444/wd/hub",
  browsers: {
    chrome: {
      browserName: "chrome",
      viewport: { width: 1024, height: 768 },
      limit: 2,
    },
  },
};

export default config;
```

**Step 3: Create .storybook/main.js**

```javascript
/** @type { import('@storybook/react-vite').StorybookConfig } */
const config = {
  stories: ["../stories/**/*.stories.@(js|jsx|ts|tsx)"],
  addons: ["@storybook/addon-essentials"],
  framework: {
    name: "@storybook/react-vite",
    options: {},
  },
};

export default config;
```

**Step 4: Create vite.config.js**

```javascript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
});
```

**Step 5: Copy stories**

```bash
cp -r cjs-webpack-sb8/stories esm-vite-sb10/
```

**Step 6: Commit**

```bash
git add esm-vite-sb10/
git commit -m "feat: add esm-vite-sb10 example project"
```

---

## Task 7: Create Playwright Docker Projects

### Task 7.1: Create playwright-esm-vite-sb9

**Files:**
- Create: `playwright-esm-vite-sb9/package.json`
- Create: `playwright-esm-vite-sb9/creevey.config.mjs`
- Create: `playwright-esm-vite-sb9/.storybook/main.js`
- Create: `playwright-esm-vite-sb9/vite.config.js`
- Create: `playwright-esm-vite-sb9/stories/`

**Step 1: Create package.json**

```json
{
  "name": "creevey-playwright-esm-vite-sb9",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^9.1.20",
    "@storybook/react": "^9.1.20",
    "@storybook/react-vite": "^9.1.20",
    "@vitejs/plugin-react": "^4.3.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "playwright-core": "^1.50.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "storybook": "^9.1.20",
    "vite": "^5.4.0"
  }
}
```

**Step 2: Create creevey.config.mjs**

```javascript
import { CreeveyConfig, PlaywrightWebdriver } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  useDocker: true,
  webdriver: PlaywrightWebdriver,
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

**Step 3: Copy remaining files**

```bash
cp esm-vite-sb9/.storybook/main.js playwright-esm-vite-sb9/.storybook/
cp esm-vite-sb9/vite.config.js playwright-esm-vite-sb9/
cp -r cjs-webpack-sb8/stories playwright-esm-vite-sb9/
```

**Step 4: Commit**

```bash
git add playwright-esm-vite-sb9/
git commit -m "feat: add playwright-esm-vite-sb9 example project"
```

---

### Task 7.2: Create playwright-esm-vite-sb10-bun

**Files:**
- Create: `playwright-esm-vite-sb10-bun/package.json`
- Create: `playwright-esm-vite-sb10-bun/bun.lockb` (generated)
- Create: `playwright-esm-vite-sb10-bun/creevey.config.mjs`
- Create: `playwright-esm-vite-sb10-bun/.storybook/main.js`
- Create: `playwright-esm-vite-sb10-bun/vite.config.js`
- Create: `playwright-esm-vite-sb10-bun/stories/`

**Step 1: Create package.json**

```json
{
  "name": "creevey-playwright-esm-vite-sb10-bun",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^10.3.1",
    "@storybook/react": "^10.3.1",
    "@storybook/react-vite": "^10.3.1",
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "playwright-core": "^1.50.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "storybook": "^10.3.1",
    "typescript": "^5.0.0",
    "vite": "^6.0.0"
  }
}
```

**Step 2: Create creevey.config.mjs**

```javascript
import { CreeveyConfig, PlaywrightWebdriver } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  useDocker: true,
  webdriver: PlaywrightWebdriver,
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

**Step 3: Copy remaining files**

```bash
cp esm-vite-sb10/.storybook/main.js playwright-esm-vite-sb10-bun/.storybook/
cp esm-vite-sb10/vite.config.js playwright-esm-vite-sb10-bun/
cp -r cjs-webpack-sb8/stories playwright-esm-vite-sb10-bun/
```

**Step 4: Commit**

```bash
git add playwright-esm-vite-sb10-bun/
git commit -m "feat: add playwright-esm-vite-sb10-bun example project"
```

---

### Task 7.3: Create playwright-esm-vite-sb10-react19

**Files:**
- Create: `playwright-esm-vite-sb10-react19/package.json` with React 19
- Create: `playwright-esm-vite-sb10-react19/creevey.config.mjs`
- Create: `playwright-esm-vite-sb10-react19/.storybook/main.js`
- Create: `playwright-esm-vite-sb10-react19/vite.config.js`
- Create: `playwright-esm-vite-sb10-react19/stories/`

**Step 1: Create package.json**

```json
{
  "name": "creevey-playwright-esm-vite-sb10-react19",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "storybook": "storybook dev --ci -p 6006",
    "build-storybook": "storybook build",
    "creevey": "creevey",
    "creevey:ui": "creevey --ui",
    "creevey:update": "creevey --update"
  },
  "devDependencies": {
    "@storybook/addon-essentials": "^10.3.1",
    "@storybook/react": "^10.3.1",
    "@storybook/react-vite": "^10.3.1",
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "creevey": "^0.10.0",
    "http-server": "^14.1.1",
    "playwright-core": "^1.50.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "storybook": "^10.3.1",
    "typescript": "^5.0.0",
    "vite": "^6.0.0"
  },
  "engines": {
    "node": ">=20.19.0 || >=22.12.0"
  }
}
```

**Step 2: Create creevey.config.mjs**

```javascript
import { CreeveyConfig, PlaywrightWebdriver } from "creevey";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/** @type {CreeveyConfig} */
const config = {
  testsDir: path.join(__dirname, "stories"),
  useDocker: true,
  webdriver: PlaywrightWebdriver,
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

**Step 3: Copy remaining files**

```bash
cp esm-vite-sb10/.storybook/main.js playwright-esm-vite-sb10-react19/.storybook/
cp esm-vite-sb10/vite.config.js playwright-esm-vite-sb10-react19/
cp -r cjs-webpack-sb8/stories playwright-esm-vite-sb10-react19/
```

**Step 4: Commit**

```bash
git add playwright-esm-vite-sb10-react19/
git commit -m "feat: add playwright-esm-vite-sb10-react19 example project"
```

---

## Task 8: Update GitLab CI Configuration

**Files:**
- Modify: `.gitlab-ci.yml`

**Step 1: Replace entire GitLab CI configuration**

```yaml
stages:
  - test

variables:
  SELENIUM_GRID_URL: "http://selenium-hub:4444/wd/hub"

# Template for Selenium-based projects
.selenium-template: &selenium-template
  image: node:20-alpine
  tags:
    - docker-build
  stage: test
  services:
    - name: selenium/hub:4.18.1-20240220
      alias: selenium-hub
    - name: selenium/node-chrome:4.18.1-20240220
      alias: selenium-node-chrome
  before_script:
    - cd $FIXTURE
    - |
      if [ -f "pnpm-workspace.yaml" ]; then
        npm install -g pnpm@9
        pnpm install
      elif [ -f ".yarnrc.yml" ]; then
        yarn install
      else
        npm install
      fi
  script:
    - npm run build-storybook
    - npx http-server ./storybook-static -p 6006 -s &
    - npx creevey --debug
  artifacts:
    paths:
      - $FIXTURE/report
    expire_in: 1 week

# Selenium Grid projects
selenium-cjs-webpack-sb8:
  <<: *selenium-template
  variables:
    FIXTURE: "cjs-webpack-sb8"

selenium-cjs-vite-sb8:
  <<: *selenium-template
  variables:
    FIXTURE: "cjs-vite-sb8"

selenium-esm-webpack-sb8:
  <<: *selenium-template
  variables:
    FIXTURE: "esm-webpack-sb8"

selenium-esm-vite-sb8:
  <<: *selenium-template
  variables:
    FIXTURE: "esm-vite-sb8"

selenium-esm-vite-sb9:
  <<: *selenium-template
  variables:
    FIXTURE: "esm-vite-sb9"

selenium-esm-vite-sb9-yarn-pnp:
  <<: *selenium-template
  variables:
    FIXTURE: "esm-vite-sb9-yarn-pnp"

selenium-esm-vite-sb9-pnpm:
  <<: *selenium-template
  variables:
    FIXTURE: "esm-vite-sb9-pnpm"

selenium-esm-vite-sb9-playwright:
  <<: *selenium-template
  image: node:20  # Playwright needs full node image
  variables:
    FIXTURE: "esm-vite-sb9-playwright"

selenium-esm-vite-sb10:
  <<: *selenium-template
  image: node:22-alpine  # SB10 requires Node 20.19+ or 22.12+
  variables:
    FIXTURE: "esm-vite-sb10"

# Playwright Docker projects
playwright-esm-vite-sb9:
  image: mcr.microsoft.com/playwright:v1.50.0-jammy
  tags:
    - docker-build
  stage: test
  variables:
    FIXTURE: "playwright-esm-vite-sb9"
  script:
    - cd $FIXTURE
    - npm install
    - npm run build-storybook
    - npx http-server ./storybook-static -p 6006 -s &
    - npx creevey --debug
  artifacts:
    paths:
      - $FIXTURE/report
    expire_in: 1 week

playwright-esm-vite-sb10-bun:
  image: oven/bun:1.2
  tags:
    - docker-build
  stage: test
  variables:
    FIXTURE: "playwright-esm-vite-sb10-bun"
  script:
    - cd $FIXTURE
    - bun install
    - bun run build-storybook
    - bunx http-server ./storybook-static -p 6006 -s &
    - bunx creevey --debug
  artifacts:
    paths:
      - $FIXTURE/report
    expire_in: 1 week

playwright-esm-vite-sb10-react19:
  image: mcr.microsoft.com/playwright:v1.50.0-jammy
  tags:
    - docker-build
  stage: test
  variables:
    FIXTURE: "playwright-esm-vite-sb10-react19"
  script:
    - cd $FIXTURE
    - npm install
    - npm run build-storybook
    - npx http-server ./storybook-static -p 6006 -s &
    - npx creevey --debug
  artifacts:
    paths:
      - $FIXTURE/report
    expire_in: 1 week
```

**Step 2: Commit**

```bash
git add .gitlab-ci.yml
git commit -m "ci: update GitLab CI for 12 new example projects with public images"
```

---

## Task 9: Update README Documentation

**Files:**
- Modify: `README.md`

**Step 1: Replace README content**

```markdown
# Creevey E2E Testing Examples

Demo configurations for Storybook 8/9/10 with Creevey, covering CJS/ESM, Webpack/Vite, multiple package managers, and runtimes.

## Projects

### Selenium Grid Projects (9 projects)

Projects using Selenium WebDriver against local Selenium Grid:

| Project | Module | Builder | Storybook | Notes |
|---------|--------|---------|-----------|-------|
| `cjs-webpack-sb8/` | CJS | Webpack 5 | 8.6.x | Legacy CJS support |
| `cjs-vite-sb8/` | CJS | Vite | 8.6.x | CJS with Vite |
| `esm-webpack-sb8/` | ESM | Webpack 5 | 8.6.x | ESM with Webpack |
| `esm-vite-sb8/` | ESM | Vite | 8.6.x | ESM base |
| `esm-vite-sb9/` | ESM | Vite | 9.1.x | SB9 base |
| `esm-vite-sb9-yarn-pnp/` | ESM | Vite | 9.1.x | Yarn PnP |
| `esm-vite-sb9-pnpm/` | ESM | Vite | 9.1.x | pnpm |
| `esm-vite-sb9-playwright/` | ESM | Vite | 9.1.x | Playwright + Selenium Grid |
| `esm-vite-sb10/` | ESM | Vite | 10.3.x | SB10 (ESM-only) |

### Playwright Docker Projects (3 projects)

Projects using Playwright with Docker-based browsers:

| Project | Module | Builder | Storybook | Runtime | Notes |
|---------|--------|---------|-----------|---------|-------|
| `playwright-esm-vite-sb9/` | ESM | Vite | 9.1.x | Node | Playwright Docker |
| `playwright-esm-vite-sb10-bun/` | ESM | Vite | 10.3.x | Bun | Bun runtime |
| `playwright-esm-vite-sb10-react19/` | ESM | Vite | 10.3.x | Node | React 19 |

## Local Development

### Prerequisites

- Node.js 20+ (or 22+ for SB10 projects)
- Docker and Docker Compose
- Bun (for bun projects)
- pnpm (for pnpm projects)

### Starting Local Selenium Grid

For Selenium-based projects:

```bash
./scripts/start-grid.sh
```

This starts a local Selenium Grid at `http://localhost:4444/wd/hub`.

### Running Tests Locally

**Selenium projects:**
```bash
# 1. Start Selenium Grid
./scripts/start-grid.sh

# 2. Run tests
cd esm-vite-sb9
npm install
npm run build-storybook
npx http-server ./storybook-static -p 6006 -s &
npx creevey

# 3. Stop grid when done
./scripts/stop-grid.sh
```

**Playwright projects:**
```bash
cd playwright-esm-vite-sb9
npm install
npm run build-storybook
npx http-server ./storybook-static -p 6006 -s &
npx creevey
```

**Bun projects:**
```bash
cd playwright-esm-vite-sb10-bun
bun install
bun run build-storybook
bunx http-server ./storybook-static -p 6006 -s &
bunx creevey
```

**pnpm projects:**
```bash
cd esm-vite-sb9-pnpm
pnpm install
pnpm run build-storybook
pnpm dlx http-server ./storybook-static -p 6006 -s &
pnpm dlx creevey
```

## CI/CD

GitLab CI includes 12 jobs covering all project variants:

- Selenium Grid jobs use `node:20-alpine` with Selenium services
- Playwright jobs use `mcr.microsoft.com/playwright` images
- Bun job uses `oven/bun:1.2`
- SB10 jobs require Node 22+

## Browser Configuration

All projects configured with:
- Chrome/Chromium browser
- 1024x768 viewport
- 2 parallel browser instances

## More Information

Read about Creevey features in the [article](https://staff.skbkontur.ru/article/63e5e042352f24389a1e9fac).
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README with 12 new project structure"
```

---

## Task 10: Verify Complete Restructure

**Step 1: Verify project structure**

```bash
ls -la /Users/ki/Projects/creevey/sb7-creevey
# Should show 12 project directories + root files
```

**Step 2: Verify no enterprise references remain**

```bash
# Check for old registry references
grep -r "nexus.kontur.host" . --include="*.json" --include="*.yml" --include="*.yaml" 2>/dev/null || echo "✓ No enterprise registry found"

# Check for old grid references
grep -r "grid.skbkontur.ru" . --include="*.ts" --include="*.mts" --include="*.js" --include="*.mjs" 2>/dev/null || echo "✓ No remote grid found"

# Check for old docker images
grep -r "docker-proxy.kontur.host" . --include="*.yml" 2>/dev/null || echo "✓ No enterprise docker images found"
```

**Step 3: Verify all creevey configs use local grid**

```bash
grep -l "localhost:4444" */creevey.config.* 2>/dev/null | wc -l
# Should show 9 (Selenium projects)
```

**Step 4: Verify package manager configs**

```bash
# Check yarn pnp
ls esm-vite-sb9-yarn-pnp/.yarnrc.yml && echo "✓ Yarn PnP config exists"

# Check pnpm
ls esm-vite-sb9-pnpm/pnpm-workspace.yaml && echo "✓ pnpm workspace exists"
```

**Step 5: Final verification commit**

```bash
git log --oneline -20
```

---

## Summary

### ✅ Complete Migration:

**Deleted (8 old projects):**
- `esm/`, `playwright-docker/`, `playwright-grid/`, `vite/`, `vite-sb8/`, `webpack/`, `webpack-sb8/`, `yarn-pnp/`

**Created (12 new projects):**

**Selenium Grid (9):**
1. `cjs-webpack-sb8/` - CJS + Webpack 5 + SB8
2. `cjs-vite-sb8/` - CJS + Vite + SB8
3. `esm-webpack-sb8/` - ESM + Webpack 5 + SB8
4. `esm-vite-sb8/` - ESM + Vite + SB8
5. `esm-vite-sb9/` - ESM + Vite + SB9 (base)
6. `esm-vite-sb9-yarn-pnp/` - ESM + Vite + SB9 + Yarn PnP
7. `esm-vite-sb9-pnpm/` - ESM + Vite + SB9 + pnpm
8. `esm-vite-sb9-playwright/` - ESM + Vite + SB9 + Playwright + Selenium Grid
9. `esm-vite-sb10/` - ESM + Vite + SB10

**Playwright Docker (3):**
10. `playwright-esm-vite-sb9/` - ESM + Vite + SB9 + Playwright Docker
11. `playwright-esm-vite-sb10-bun/` - ESM + Vite + SB10 + Bun
12. `playwright-esm-vite-sb10-react19/` - ESM + Vite + SB10 + React 19

### Files Changed:
- **Deleted:** 8 entire project directories (160+ files)
- **Created:** 12 new project directories (120+ files)
- **Modified:** `.gitlab-ci.yml`, `README.md`, `.gitignore`
- **Created:** `docker-compose.yml`, `scripts/start-grid.sh`, `scripts/stop-grid.sh`

**Total:** ~300 files changed, comprehensive restructure complete!
