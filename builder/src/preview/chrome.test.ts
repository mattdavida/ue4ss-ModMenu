import { describe, expect, it } from "vitest";
import { buttonChrome } from "./chrome";

describe("buttonChrome", () => {
  it("disabled wins over active and variant", () => {
    expect(buttonChrome({ enabled: false, active: true, variant: "danger" })).toEqual({
      background: "var(--mm-button-bg-disabled)",
      color: "var(--mm-button-text-disabled)",
    });
  });

  it("active wins over variant", () => {
    expect(buttonChrome({ active: true, variant: "primary" })).toEqual({
      background: "var(--mm-button-bg-active)",
      color: "var(--mm-button-text-active)",
    });
  });

  it("maps accent to primary", () => {
    expect(buttonChrome({ variant: "accent" })).toEqual({
      background: "var(--mm-button-bg-primary)",
      color: "var(--mm-button-text-primary)",
    });
  });
});
