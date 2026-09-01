import { describe, expect, it } from "vitest";
import { DEFAULT_KEY, TOGGLE_KEYS, isToggleKey } from "./keys";

describe("toggle keys", () => {
  it("defaults to F6 and lists UE4SS function keys", () => {
    expect(DEFAULT_KEY).toBe("F6");
    expect(isToggleKey("F6")).toBe(true);
    expect(isToggleKey("F8")).toBe(true);
    expect(TOGGLE_KEYS).toContain("F12");
    expect(isToggleKey("LEFT_MOUSE_BUTTON")).toBe(false);
  });
});
