import { describe, expect, it } from "vitest";
import { formatOptions, parseOptions } from "./optionsText";

describe("optionsText", () => {
  it("round-trips strings and label|value", () => {
    const options = ["Gold", { label: "Bee", value: "b" }];
    expect(parseOptions(formatOptions(options))).toEqual(options);
  });
});
