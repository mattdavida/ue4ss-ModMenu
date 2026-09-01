# ModMenu Builder — working plan

A lightweight React app so visual people can compose a menu from **known widgets**, create tabs / sections, and export a **skeleton** (JSON) or **Lua** without learning the Register tables.

This file is the checklist we iterate against. Not a one-shot spec. Update it as we learn.

North-star look: `GithubAssets/ModMenuHero.png` / `ModMenuHero2.png`. Runtime contract: `README.md` item types + `widgets/*.lua` `validate`.

---

## Same page

| Role | Owns |
|------|------|
| Builder | Schema document (tabs, sections, folds, rows, widget fields) |
| Preview | Desktop light / dark panel that matches theme tokens |
| Export JSON | Same document — reopen later, hand off |
| Export Lua | Valid host `main.lua`: `Init` + `Register`, stubs for `onClick` / `onChange` / defaults |
| Host author (later) | Game calls inside the stubs. `SetOptions` / `OnOpen` / `SetButton*` stay comments, not generated logic |

They never need the README item tables to get a working shell. They still need someone to wire game functions.

---

## Principles

1. **Schema is the source of truth.** The canvas edits a document. Preview and both exporters read that document. Do not hardcode widget fields in three places.
2. **Export must `Register`.** Nest rules and required fields match `widgets/*.lua`. Illegal trees are blocked in the editor, not after download.
3. **Preview = tokens + hierarchy, not pixel-perfect UMG.** Default desktop scale, light and dark. No overlay cursor, no touch checkbox-as-buttons, no real ComboBoxString.
4. **Not in the player zip.** Lives beside the library (`builder/`). Do not fold into Studio or `ModMenu.zip`.
5. **Iterate.** Each slice should run in the browser and leave the document / export honest.

---

## Out of v1

- Color-token editor, custom themes beyond light / dark
- `inputBackend`, `cursorMode`, `cursorHideClasses`, `canOpen`, `pointerMode`, `fontScale`
- Generated `OnOpen` / `SetOptions` / `SetButton*` / ConfigManager wiring
- Lua → schema import
- Free-form design canvas (no absolute positioning)
- Pixel-perfect engine fonts / handheld layout

---

## Document shape (draft)

JSON the builder saves. Refine when we implement the schema file.

```
{
  version: 1,
  init: {
    title, instanceId, keyHint, dock, theme,
    tabs?: string[]          // omit = single scroll
  },
  sections: [{
    id, title, tab?,         // tab must be in init.tabs when tabs are on
    collapsible?, collapsed?,
    items: Item[]
  }]
}

Item =
  | { type: "separator" }
  | { type: "label", id?, label }
  | { type: "button", id, label, variant?, enabled?, active?, confirm? }
  | { type: "checkbox", id, label, default? }
  | { type: "dropdown", id, label, options, default?, searchable?, placeholder?, … }
  | { type: "number", id, label, default?, min?, max?, integer?, … }
  | { type: "textinput", id, label, default?, placeholder?, … }
  | { type: "row", items: Item[] }     // button | checkbox | label | number | textinput
  | { type: "fold", id, label, collapsed?, items: Item[] }
      // no nested fold; row is allowed inside fold
```

Callbacks are **not** stored as functions. The Lua printer emits stubs. Optional later: a `comment` string per item that becomes a `--` line in the stub.

Ids must be unique within a section (including fold / row children) — same as `Get` / `Set`.

---

## Slices

Tick these in order. Stop and preview after each. Adjust this list instead of jumping ahead.

### 0. Scaffold

- [x] `builder/` Vite + React + TypeScript
- [x] README stub: how to run, what it exports, link to this plan
- [x] `npm` script at repo root (`npm run builder`) — optional, can wait
- [x] Do **not** add builder to `tools/bundle.mjs` / player zip

### 1. Schema

- [x] `builder/src/schema/` — types + defaults + nest rules + id uniqueness
- [x] Validate function that mirrors `widgets/*.lua` (row / fold allow-lists, required id / label)
- [x] One fixture document that matches `examples/ModMenuHost.lua` structure (Cheats / Give / Keybinds) — used by preview and export tests
- [x] Snapshot or unit test: fixture is valid; illegal row/fold trees fail

### 2. Theme tokens + static preview

- [x] Port `core/theme.lua` light / dark tokens into TS (same key names, 0–1 RGB)
- [x] Read-only docked panel: title, `[key] toggle`, Dock row, optional tabs, sections, items
- [x] Widget chrome: button variants, active / disabled, checkbox, dropdown header, number / text fields, fold `+` / `-`, section collapse
- [x] Theme toggle on the page (not a player setting — author preview)
- [x] Compare against hero shots; fix spacing / type until it feels like the dummy, not a generic form

### 3. Editor (palette + inspector + tree)

v1 editor is **not** a free-form DnD canvas. It is:

- Palette of known types (the nine widgets + “tab” + “section”)
- Outline / tree of the document
- Inspector for the selected node
- Add / remove / reorder; drop onto a legal parent

- [x] Select section / item; edit label, id, defaults, variant, options, confirm copy, collapsible
- [x] Add tab; assign section `tab`
- [x] Enforce nest rules on add / move (reject dropdown-into-row, fold-into-fold)
- [x] Auto-id from label when empty; warn on collision
- [x] Empty states: no tabs, no sections, empty section

Drag-and-drop for reorder / “drop onto section” is **this slice if it stays simple**, otherwise a follow-on. Do not block export on polished DnD.

### 4. Export

- [x] **Download JSON** — the document as-is (`version`, `init`, `sections`)
- [x] **Download Lua** — `Scripts/main.lua` shape:
  - `require("ModMenu.ModMenu")`
  - `Init({ title, instanceId, key, keyHint, dock, theme, tabs? })`
  - one `Register` per section
  - stubs: `onClick` / `onChange` with `-- TODO: game call` and a `ModMenu.Get(...)` hint where useful
  - `default` / `min` / `max` / `options` / `confirm` filled from the document
  - header comment: wire game logic; see README Dynamic UI for `SetOptions` / `OnOpen`
- [x] Printer test: fixture Lua contains expected `Register` ids and does not emit functions we do not have
- [x] Optional: copy-to-clipboard for both

`Key.F6` (etc.) from `keyHint` when it is a plain function-key name; otherwise emit a comment to set `key` / `keyName` by hand.

Primary button is **Export zip**: drop into `ue4ss/Mods/` — `<instanceId>/enabled.txt` + `Scripts/main.lua` **and** `shared/ModMenu/ModMenu.lua` (runtime baked at builder build time). Copy Lua and JSON are extras. Extracting overwrites `shared/ModMenu` with that snapshot.

### 5. Load + empty start

v1 already has New + Example. Open-from-file and autosave are follow-ons.

- [x] New menu (sensible defaults: title, one section, no tabs)
- [x] Parse + adopt JSON (`adoptJson`) — file / paste / autosave share this
- [x] Open JSON (file) — bad file keeps the current doc + bar error
- [ ] Paste JSON (skipped for now)
- [x] Load the ModMenuHost fixture as a “example” so people can poke a full tree
- [x] localStorage autosave so a refresh does not wipe work
- [x] Confirm before New / Example / Open replaces the current menu

---

## Follow-ons (not blocking v1)

| Later | Notes |
|-------|--------|
| Paste JSON | Optional; file Open covers the same adopt path |
| Drag-and-drop polish | Palette → tree / preview drop targets |
| Lua import | Parse `Init` / `Register` tables — hard, skip until someone needs it |
| Schema generated from Lua | Keep TS types next to `validate` by hand for v1; codegen if widgets churn |
| `comment` on items | Becomes `--` in the stub |
| GitHub Pages | Shipped: Actions deploys `builder/dist` to `https://mattdavida.github.io/ue4ss-ModMenu/` |
| Init extras as an “advanced” inspector | `ignoreLook`, `showClose`, `consoleCommand` only — still no cursor / input backends |

---

## File map (target)

```
builder/
  plan.md              ← this file can move here later; keep one plan
  package.json
  src/
    schema/            types, validate, defaults, fixture
    theme/             light / dark tokens from core/theme.lua
    preview/           docked panel (read-only)
    editor/            palette, tree, inspector
    export/            json + lua printers
    App.tsx
```

Repo root `package.json` stays the library scripts. Builder has its own.

---

## Acceptance (v1)

1. A person who has never read the README can add tabs, sections, and widgets, then export a host zip / Lua.
2. That Lua `require`s ModMenu and `Register`s without errors (stubs are empty functions). Load banner matches the Fatal Claw / Host box.
3. Preview is recognizably ModMenu (hero-shot family), light and dark.
4. JSON can be downloaded (re-open is a follow-on).
5. Illegal nests cannot be built.

**v1 is this loop:** compose → preview → export. Shipped 2026-08-31.

---

## Current slice

**v1 done.** Load/save/replace, e2e, and Pages deploy are in. Enable Pages (Settings → GitHub Actions) after this is on `main`.

### Notes

- **0 + 1 (2026-08-31):** Vite React TS under `builder/`. Schema + `validateDocument` + ModMenuHost fixture + Vitest. Page only shows fixture validity — no preview yet. `create-vite@9` needs `npx create-vite --template react-ts` (npm `-- --template` was eaten as npm config).
- **2 (2026-08-31):** `core/theme.lua` tokens → CSS vars. Docked panel preview of the fixture (tabs, dock picker, collapse / fold, widget chrome, confirm overlay). Theme toggle is author-only. Preview fonts follow Host dummy density, not Init 22/16 defaults. Fields are display-only.
- **3 (2026-08-31):** Palette + outline + inspector. Nest rules live in `editor/model.ts` (illegal types insert after the parent, not inside). Reorder is Up/Down, not drag-and-drop. New / Example in the bar (also on the slice 5 list). Id collision warns; empty id suggests a slug.
- **4 (2026-08-31):** Export zip is the main action (host folder + `main.lua` stubs). Copy Lua + download JSON beside it. No ModMenu runtime in the zip. Load `print` banner after Init (title / key / tabs / dock).
- **v1 (2026-08-31):** Compose + preview + export is enough. Slice 5 leftover (open JSON / localStorage) is a follow-on.
- **5 parse (2026-08-31):** `adoptJson` — JSON.parse, require `version === 1` + `init` + `sections`, `ensureIds`, collect `validateDocument` issues. Garbage gets a one-line reason. Not wired to the bar yet.
- **5 open (2026-08-31):** Bar **Open** (hidden `accept` JSON). `adoptJson` success → `load()`. Failure keeps the current document and shows the reason in the bar. No zip import.
- **5 persist + replace (2026-08-31):** `localStorage` key `modmenu-builder:doc:v1`. Boot via `adoptJson`. Debounce 300ms on edits; New / Example / Open save immediately. Quota fails quiet. Replace uses a styled `<dialog>` (not `window.confirm`). Paste skipped.
- **e2e (2026-08-31):** Playwright (`npm run test:e2e` / `npm run builder:e2e`). Chromium only. Replace dialog, compose button, JSON round-trip, autosave reload, bad Open. Not a widget encyclopedia.
- **Pages (2026-08-31):** `.github/workflows/pages.yml` builds `builder/` with `GITHUB_PAGES_BASE=/<repo>/` and deploys `dist`. Local / e2e keep `base: /`. First time: Settings → Pages → Source: GitHub Actions.
- **Export + runtime (2026-08-31):** Builder zip includes `shared/ModMenu/ModMenu.lua` from `npm run bundle` (Vite virtual module). Drop into `ue4ss/Mods/`. Copy Lua is still host-only.
- **CI Vitest (2026-08-31):** `builder` job on CI (`npm test` in `builder/`). Windows deploy waits on it. Playwright stays local.
