import { MODMENU_BUNDLE } from "virtual:modmenu-runtime";
import { describe, expect, it } from "vitest";
import { emptyDocument, hostFixture } from "../schema";
import { hostFolderName, printLua } from "./lua";
import { hostZip } from "./hostZip";

describe("printLua", () => {
  it("emits Init + Register for the Host fixture", () => {
    const lua = printLua(hostFixture);
    expect(lua).toContain('local ModMenu = require("ModMenu.ModMenu")');
    expect(lua).toContain('title = "ModMenu Host"');
    expect(lua).toContain("key = Key.F8");
    expect(lua).toContain('tabs = { "Cheats", "Give", "Keybinds" }');
    expect(lua).toContain('id = "Toggles"');
    expect(lua).toContain('id = "Give"');
    expect(lua).toContain("onChange = function(on)");
    expect(lua).toContain("onClick = function()");
    expect(lua).toContain("-- TODO: game call");
    expect(lua).toContain("ModMenu Host Loaded");
    expect(lua).toContain("F8 = toggle menu");
    expect(lua).toContain("Tabs: Cheats / Give / Keybinds");
    expect(lua).toContain("Dock: left");
    expect(lua).toContain("shared/ModMenu/");
    expect(lua).not.toMatch(/not bundled here/);
    expect(lua).not.toMatch(/ModMenu\.SetOptions\(/);
    expect(lua).not.toMatch(/ModMenu\.OnOpen\(/);
  });

  it("emits Key from a plain keyHint", () => {
    const lua = printLua(emptyDocument());
    expect(lua).toContain("key = Key.F6");
    expect(lua).toContain("My Mod Menu Loaded");
    expect(lua).toContain('id = "Main"');
    expect(hostFolderName(emptyDocument())).toBe("MyMod");
  });

  it("comments when keyHint is not a Key name", () => {
    const doc = emptyDocument();
    doc.init.keyHint = "Left Alt";
    const lua = printLua(doc);
    expect(lua).toContain("-- TODO: set key / keyName by hand");
    expect(lua).not.toContain("key = Key.");
  });
});

describe("hostZip", () => {
  it("builds a zip with the host folder and shared/ModMenu", () => {
    const { filename, bytes } = hostZip(emptyDocument());
    expect(filename).toBe("MyMod.zip");
    expect(bytes[0]).toBe(0x50);
    expect(bytes[1]).toBe(0x4b);
    const asText = new TextDecoder().decode(bytes);
    expect(asText).toContain("MyMod/enabled.txt");
    expect(asText).toContain("MyMod/Scripts/main.lua");
    expect(asText).toContain("shared/ModMenu/ModMenu.lua");
    expect(asText).toContain("ModMenu.Init");
    expect(asText).toContain("ModMenu.bundle.lua");
    expect(MODMENU_BUNDLE).toContain("package.preload");
    expect(MODMENU_BUNDLE).toContain("ModMenu.core.util");
  });
});
