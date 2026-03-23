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
