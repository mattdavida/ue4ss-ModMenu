# ModMenu refactor plan

Goal: split the ~1557-line `ModMenu.lua` monolith into a **thin shell + widget registry** so new controls (and later tabs) are additive, PR-friendly, and keep the public API stable.

**Non-goals for this refactor**

- Change host usage (`require("ModMenu.ModMenu")`, `Init` / `Register` / `Get` / `Set` / …)
- Redesign visuals or hotkeys
- Add tabs or new widget types in the same PR as the extract (land structure first, then extend)

**Success criteria**

- [ ] DevToolsMasterMod works unchanged (F6, dock, Max Rank, Items searchable give-flow)
- [ ] Each item `type` lives in its own module with a shared contract
- [ ] Adding a new type = new file + one register line + README row
- [ ] `ModMenu.lua` is mostly shell, layout, values store, and public API
- [ ] Nexus player zip still ships only runtime Lua (no docs/assets required in zip)

---

## Current state (what hurts)

| Area | Location (approx) | Notes |
|------|-------------------|--------|
| UMG helpers | `Construct`, `StyleText`, `CreateTextButton`, … | Shared by all widgets → **Phase 1 → `core/`** |
| Dropdown | `CreateDropdown` → `PollSearchableDropdowns` | Largest blob; filter + FName rows |
| Build loop | `BuildContent` | Giant `if item.type == …` switch |
| Poll loop | `PollControls` | Same switch for click handling |
| Validate | `ValidateItem` / `SUPPORTED_TYPES` | Hard-coded type list |
| Public API | `ModMenu.*` | Keep as the only host-facing surface |

Hosts (`DevToolsMasterMod`) should not need edits if the extract is internal-only.

---

## Target layout

```
shared/ModMenu/
  ModMenu.lua                 -- public API + shell + BuildContent orchestration
  refactor-plan.md            -- this file
  README.md                   -- update after Phase 2 (widget contract)
  GithubAssets/               -- docs only; not in Nexus zip

  core/                       -- Phase 1 ✅
    util.lua
    umg.lua
    input.lua
    options.lua

  widgets/                    -- Phase 2
    init.lua                  -- registry: type -> module
    button.lua
    checkbox.lua
    dropdown.lua
    label.lua
    separator.lua
```

**Require paths** (UE4SS `shared` style):

```lua
local Widgets = require("ModMenu.widgets.init")
local Umg = require("ModMenu.core.umg")
```

Keep a single entry: `require("ModMenu.ModMenu")` for hosts.

---

## Widget contract

Every widget module returns a table:

```lua
local Button = {}
Button.type = "button"
function Button.validate(item, sectionId, index) end
function Button.seed(sectionId, item, values) end
function Button.build(ctx) end
function Button.poll(ctrl, ctx) end
function Button.apply(ctrl, value, ctx) end
return Button
```

### Build context (`ctx`)

| Field | Purpose |
|-------|---------|
| `contentBox` | Parent vertical box |
| `section` / `item` | Current section + item |
| `namePrefix` | Unique FName prefix |
| `values` / `liveControls` | Shared store + control records |
| `config` / `umg` / `input` / `options` | Fonts + helpers |
| `ValueKey` / `SafeCall` | Keys + protected callbacks |

---

## Phased work

### Phase 0 — Prep ✅

v1 shipped / committed on `main`; safe rollback point.

### Phase 1 — Extract `core/` (no behavior change) ✅ done (reapplied)

1. `core/util.lua` — Log, IsValid, ToPlainString, ValueKey, SafeCall  
2. `core/umg.lua` — Construct stack + CreateTextButton / CreateLabeledToggle / AddSpacer  
3. `core/input.lua` — mouse latch + hover helpers + `ClearClickState`  
4. `core/options.lua` — NormalizeOptions, OptionMatchesFilter, GetWidgetPlainText  

**Gate:** full DevTools smoke pass (in-game).

### Phase 2 — Extract widgets (behavior-preserving) ✅ done

```
widgets/
  init.lua          — registry
  separator.lua
  label.lua
  button.lua
  checkbox.lua
  dropdown.lua      — create / poll / apply / refreshLive / collapseAll
```

`BuildContent` / `PollControls` / `Register` seed / `Set` / `SetLabel` / `SetOptions` dispatch via `Widgets.get(...)`.
`ModMenu.lua` ~840 lines (shell + public API).

**Gate:** same smoke + category `SetOptions` + language re-Register (in-game).

### Phase 3 — Cleanup & docs

- README: widget contract + disk layout (`core/`, `widgets/`)
- Nexus zip: ship `ModMenu.lua` + `core/` + `widgets/` only

### Phase 4 — Soft API polish (optional)

- `Set` / `SetLabel` / `SetOptions` via `widget.apply`
- Seed on Register via `widget.seed`

---

## Packaging note (Nexus)

```
Mods/DevToolsMasterMod/...
Mods/shared/ModMenu/ModMenu.lua
Mods/shared/ModMenu/core/*.lua
Mods/shared/ModMenu/widgets/*.lua   -- after Phase 2
```

Omit: `README.md`, `refactor-plan.md`, `GithubAssets/`.

---

## Next steps (after refactor)

### 1. Tabbed support

- Optional `tab = "Items"` on `Register`
- ≤1 tab → no tab bar
- Else: tab buttons under dock; build active tab only
- Values store survives tab switches

### 2. More UI widgets

| Type | Use case |
|------|----------|
| `textinput` / `input` | Free-text / custom amounts |
| `slider` | Multipliers |
| `number` | Integer stepper |

### 3. Backlog

- Persist dock + active tab
- Cap / virtualize huge lists
- Snapshot expand/filter across rebuilds

---

## Manual smoke checklist

- [ ] Game + UE4SS load; no `ModMenu.core.*` require errors
- [ ] F6 toggles menu; mouse + GameAndUI
- [ ] Dock Left ↔ Right
- [ ] Max buddy / Max Kagura
- [ ] Max SP / Add amber
- [ ] Item DB status populates (load a save)
- [ ] Category filter refreshes item list
- [ ] Search + Give item
- [ ] Language switch without crash
- [ ] Close / reopen
