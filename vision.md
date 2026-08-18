# ModMenu Vision

North-star for a dense, scannable in-game settings shell on UE4SS + constructed UMG.

The main push is **shipped**. This file is no longer a phase plan. README is the API; leftovers below are optional follow-ons, not a committed roadmap.

Hero shots: `GithubAssets/ModMenuHero.png` and `ModMenuHero2.png` (README).

---

## North star (in UMG)

A host can ship a cheat / tools panel that feels intentional:

- Hierarchy: **title → tabs (optional) → collapsible sections → `fold` → controls**
- Dense but readable (collapse + tabs beat one endless scroll)
- Author light / dark themes (`Init`; not a player picker)
- Same API shape (`Init` / `Register` / widgets)
- UE4.27+ and UE5 without per-game forks in core

Constructed UMG is flat colors — no CSS, bevels, or hover glow.

---

## Principles

1. **Framework, not a game mod** — hosts own cursors, pause locks, native utils.
2. **Theme tokens over magic numbers** — widgets read `config.colors`.
3. **Widget contract stays sacred** — new types = `widgets/*.lua` + registry + README (`widgets/*.lua` auto-bundle).
4. **Defaults stay boring** — denser looks are opt-in via `Init`.
5. **UE4 / UE5 parity** — probe / fallback for engine arity.

---

## Shipped

- Per-mod shell, dock left/right, deploy bundle
- Author themes (`light` / `dark` + color overrides)
- Collapsible sections + nested `fold`
- Optional tabs (`Init({ tabs = { ... } })` + `Register({ tab = ... })`)
- Widgets: `checkbox`, `button` (variants / active / enabled), `dropdown` (searchable), `label`, `separator`, `number`, `textinput`, `row`, `fold`
- Showcase dummy: `examples/ModMenuHost.lua`

---

## Intentionally out of core

- Game-specific software cursors (host glyph if the engine cursor is suppressed)
- Player-facing theme picker
- Drag-anywhere placement (dock presets only)
- CommonUI / Enhanced Input / designer WBP
- Two shells receiving clicks at once (close one to use the other; dual-open input is later)

---

## Optional later

Not blocking a “vision shipped” claim. Pick these when a host actually needs them.

| Leftover | Notes |
|----------|--------|
| 2-column action grids | `row` is the current workaround |
| Hover / pressed restyle | Constructed `UButton` is flat fill |
| Header Close control | Hint + hotkey already close |
| `slider` / `radio` | Dropdown + number cover most hosts |
| Checkbox / separator tokens | Native checkbox tint; separator is still a spacer |
| Tab Q/E | Mouse strip is v1 |
| Extra spacing tokens | `gapItem` / `gapSection` still hardcoded |
