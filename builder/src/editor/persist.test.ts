import { describe, expect, it } from "vitest";
import { hostFixture } from "../schema";
import { STORAGE_KEY, bootDocument, loadStored, saveStored } from "./persist";

function memory(seed: Record<string, string> = {}) {
  const data = { ...seed };
  return {
    getItem(key: string) {
      return key in data ? data[key] : null;
    },
    setItem(key: string, value: string) {
      data[key] = value;
    },
    data,
  };
}

describe("persist", () => {
  it("round-trips a document through storage", () => {
    const store = memory();
    saveStored(hostFixture, store);
    const loaded = loadStored(store);
    expect(loaded).not.toBeNull();
    expect(loaded?.init.title).toBe(hostFixture.init.title);
    expect(loaded?.init.instanceId).toBe(hostFixture.init.instanceId);
    expect(loaded?.sections.map((section) => section.id)).toEqual(
      hostFixture.sections.map((section) => section.id),
    );
  });

  it("returns null for missing or garbage storage", () => {
    expect(loadStored(memory())).toBeNull();
    expect(loadStored(memory({ [STORAGE_KEY]: "{}" }))).toBeNull();
    expect(loadStored(memory({ [STORAGE_KEY]: "Init({})" }))).toBeNull();
  });

  it("bootDocument uses storage when valid, otherwise New defaults", () => {
    const empty = bootDocument(memory());
    expect(empty.init.title).toBe("My Mod Menu");
    const stored = bootDocument(memory({ [STORAGE_KEY]: JSON.stringify(hostFixture) }));
    expect(stored.init.title).toBe("ModMenu Host");
  });

  it("saveStored swallows quota errors", () => {
    expect(() => {
      saveStored(hostFixture, {
        getItem: () => null,
        setItem: () => {
          throw new Error("QuotaExceededError");
        },
      });
    }).not.toThrow();
  });
});
