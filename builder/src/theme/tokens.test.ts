import { describe, expect, it } from "vitest";
import { DARK, LIGHT, THEME_KEYS } from "./tokens";
import { colorCss, themeVars } from "./css";

describe("theme tokens", () => {
  it("light and dark define every Lua key", () => {
    for (const key of THEME_KEYS) {
      expect(LIGHT[key], key).toBeDefined();
      expect(DARK[key], key).toBeDefined();
    }
  });

  it("emits CSS vars for each token", () => {
    const vars = themeVars("dark");
    expect(vars["--mm-panel-bg"]).toBe(colorCss(DARK.panelBg));
    expect(vars["--mm-button-bg-danger"]).toBe(colorCss(DARK.buttonBgDanger));
    expect(vars["--mm-pad-left"]).toBe("16px");
  });
});
