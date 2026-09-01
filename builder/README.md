# ModMenu Builder

Lightweight React app: compose a menu from the widgets ModMenu already ships, then export a **JSON skeleton** or **Lua** `main.lua` (`Init` + `Register` + stubs). You do not need to learn the Register tables to lay out tabs and controls.

Runtime contract: repo `README.md` item types + `widgets/*.lua`.

This folder is **not** in the player zip. Do not add it to `tools/bundle.mjs`.

## Run

```bash
npm install
npm run dev
```

From the repo root: `npm run builder`.

Hosted (after merge to `main` + Pages source = GitHub Actions): [https://mattdavida.github.io/ue4ss-ModMenu/](https://mattdavida.github.io/ue4ss-ModMenu/). Static UI only — menus stay in the browser. **Export zip** is drop-in: extract into `ue4ss/Mods/` (host folder + `shared/ModMenu`).

## Scripts

| Script | |
|--------|--|
| `npm run dev` | Vite dev server |
| `npm run build` | Typecheck + production bundle |
| `npm test` | Unit tests (Vitest) |
| `npm run test:e2e` | Golden-path browser tests (Playwright) |
| `npm run preview` | Serve the production build |

## v1

Compose (palette / outline / inspector) → themed preview → **Export zip** (`<instanceId>/` + `shared/ModMenu/ModMenu.lua`). Copy Lua / JSON are extras. Game calls stay as stubs. Extracting a zip overwrites `shared/ModMenu` with the runtime this builder was built from.

Open JSON, autosave, and a replace dialog are in.
