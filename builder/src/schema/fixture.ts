import { DOCUMENT_VERSION } from "./types";
import type { MenuDocument } from "./types";

/** Same tree as examples/ModMenuHost.lua (structure only — no callbacks). */
export const hostFixture: MenuDocument = {
  version: DOCUMENT_VERSION,
  init: {
    title: "ModMenu Host",
    instanceId: "ModMenuHost",
    keyHint: "F8",
    dock: "left",
    theme: "dark",
    tabs: ["Cheats", "Give", "Keybinds"],
  },
  sections: [
    {
      id: "Status",
      title: "Status",
      tab: "Cheats",
      items: [
        {
          type: "label",
          id: "last",
          label: "Ready — clicks log here and in the UE4SS console.",
        },
        {
          type: "button",
          id: "gotoGive",
          label: "Go to Give tab",
          variant: "info",
        },
      ],
    },
    {
      id: "Toggles",
      title: "Toggles",
      tab: "Cheats",
      items: [
        { type: "checkbox", id: "god", label: "God mode (mock)", default: false },
        { type: "checkbox", id: "noclip", label: "Noclip (mock)", default: false },
        {
          type: "dropdown",
          id: "difficulty",
          label: "Difficulty",
          options: ["Easy", "Normal", "Hard"],
          default: "Normal",
        },
        {
          type: "row",
          items: [
            {
              type: "number",
              id: "healAmt",
              label: "Heal",
              default: 100,
              min: 1,
              max: 9999,
              integer: true,
              labelWidth: 48,
            },
            { type: "button", id: "heal", label: "Apply", variant: "success" },
          ],
        },
        {
          type: "textinput",
          id: "note",
          label: "Note",
          default: "",
          placeholder: "type then press Log",
          labelWidth: 48,
        },
        { type: "button", id: "logNote", label: "Log note" },
      ],
    },
    {
      id: "Buttons",
      title: "Button styles",
      tab: "Cheats",
      collapsible: true,
      collapsed: false,
      items: [
        { type: "label", label: "Variants (flat UMG). Watch the console." },
        { type: "button", id: "vDefault", label: "default" },
        { type: "button", id: "vPrimary", label: "primary", variant: "primary" },
        { type: "button", id: "vSecondary", label: "secondary", variant: "secondary" },
        { type: "button", id: "vSuccess", label: "success", variant: "success" },
        { type: "button", id: "vDanger", label: "danger", variant: "danger" },
        { type: "button", id: "vWarning", label: "warning", variant: "warning" },
        { type: "button", id: "vInfo", label: "info", variant: "info" },
        { type: "separator" },
        { type: "label", label: "Live chrome — no rebuild (SetButton*)." },
        { type: "button", id: "modeA", label: "Mode A", active: true },
        { type: "button", id: "modeB", label: "Mode B" },
        { type: "button", id: "flip", label: "Flip primary / danger", variant: "primary" },
        { type: "button", id: "gateToggle", label: "Enable gated button", variant: "secondary" },
        { type: "button", id: "gated", label: "Gated action", enabled: false },
      ],
    },
    {
      id: "Give",
      title: "Give item",
      tab: "Give",
      items: [
        { type: "label", label: "Searchable dropdown + amount row. Mock catalog only." },
        {
          type: "dropdown",
          id: "item",
          label: "Item",
          searchable: true,
          placeholder: "Select item...",
          maxVisible: 8,
          options: [
            "Ashen Flask",
            "Gold Coin",
            "Tarstone",
            "Shell Fragment",
            "Resolve Shard",
            "Gloom Essence",
            "Laterite",
            "Mask of Harros",
            "Sidearm Kit",
            "Weapon Oil",
          ],
        },
        {
          type: "row",
          items: [
            {
              type: "number",
              id: "amount",
              label: "Amt",
              default: 1,
              min: 1,
              max: 99,
              integer: true,
              labelWidth: 36,
            },
            { type: "button", id: "give", label: "Give", variant: "primary" },
          ],
        },
        { type: "button", id: "swapCatalog", label: "Swap catalog (SetOptions)", variant: "secondary" },
        {
          type: "fold",
          id: "giveAll",
          label: "Give all (hidden)",
          collapsed: true,
          items: [
            { type: "label", label: "Destructive mock — still only logs." },
            {
              type: "button",
              id: "giveAllBtn",
              label: "Give ALL items",
              variant: "warning",
              confirm: {
                title: "Give all items?",
                message: "Mock grant of every catalog item. This cannot be undone here.",
                confirmLabel: "Give all",
              },
            },
          ],
        },
      ],
    },
    {
      id: "Bags",
      title: "Currencies",
      tab: "Give",
      items: [
        {
          type: "dropdown",
          id: "currency",
          label: "Kind",
          options: ["Gold", "Gloom", "Tarcores"],
          default: "Gold",
        },
        {
          type: "row",
          items: [
            {
              type: "number",
              id: "qty",
              label: "Qty",
              default: 100,
              min: 1,
              integer: true,
              labelWidth: 36,
            },
            { type: "button", id: "add", label: "Add" },
          ],
        },
      ],
    },
    {
      id: "Keybinds",
      title: "Keybinds",
      tab: "Keybinds",
      collapsible: true,
      collapsed: false,
      items: [
        { type: "label", label: "Session-only mock. Real hosts store a key per row." },
        {
          type: "fold",
          id: "combatBinds",
          label: "Combat",
          collapsed: true,
          items: [
            { type: "button", id: "bindHeal", label: "Heal: none" },
            { type: "button", id: "bindResolve", label: "Resolve: none" },
          ],
        },
        {
          type: "fold",
          id: "uiBinds",
          label: "UI",
          collapsed: true,
          items: [
            { type: "button", id: "clearBinds", label: "Clear mock binds", variant: "danger" },
          ],
        },
      ],
    },
    {
      id: "Advanced",
      title: "Collapsed section",
      tab: "Keybinds",
      collapsible: true,
      collapsed: true,
      items: [
        { type: "label", label: "This whole section starts closed (collapsible = true)." },
        { type: "button", id: "peek", label: "Peek" },
      ],
    },
  ],
};
