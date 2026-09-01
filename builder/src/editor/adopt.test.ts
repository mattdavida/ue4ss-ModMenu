import { describe, expect, it } from "vitest";
import { printJson } from "../export/download";
import { hostFixture } from "../schema";
import { adoptJson } from "./adopt";

function okDoc(text: string) {
  const result = adoptJson(text);
  expect(result.ok).toBe(true);
  if (!result.ok) {
    throw new Error(result.reason);
  }
  return result;
}

describe("adoptJson", () => {
  it("round-trips the host fixture through printJson", () => {
    const result = okDoc(printJson(hostFixture));
    expect(result.issues).toEqual([]);
    expect(result.document.init).toEqual(hostFixture.init);
    expect(result.document.sections.map((section) => section.id)).toEqual(
      hostFixture.sections.map((section) => section.id),
    );
    expect(result.document.sections[1].items.map((item) => ("id" in item ? item.id : item.type))).toEqual(
      hostFixture.sections[1].items.map((item) => ("id" in item ? item.id : item.type)),
    );
  });

  it("rejects empty object", () => {
    const result = adoptJson("{}");
    expect(result.ok).toBe(false);
    if (result.ok) {
      return;
    }
    expect(result.reason).toMatch(/version/);
  });

  it("rejects non-JSON with a one-line reason", () => {
    const result = adoptJson("Init({ title = 'nope' })");
    expect(result.ok).toBe(false);
    if (result.ok) {
      return;
    }
    expect(result.reason).toBe("not valid JSON");
  });

  it("fills missing widget ids", () => {
    const result = okDoc(
      JSON.stringify({
        version: 1,
        init: { title: "Heal Menu", instanceId: "Heal", keyHint: "F6", dock: "right", theme: "dark" },
        sections: [
          {
            id: "Main",
            title: "Main",
            items: [{ type: "button", id: "", label: "Heal" }],
          },
        ],
      }),
    );
    expect(result.issues).toEqual([]);
    const button = result.document.sections[0].items[0];
    expect(button.type).toBe("button");
    expect("id" in button && button.id).toBe("main_heal");
  });

  it("loads an illegal nest and keeps validate issues", () => {
    const result = okDoc(
      JSON.stringify({
        version: 1,
        init: { title: "Bad", instanceId: "Bad", keyHint: "F6", dock: "right", theme: "dark" },
        sections: [
          {
            id: "Main",
            title: "Main",
            items: [
              {
                type: "row",
                items: [
                  {
                    type: "dropdown",
                    id: "diff",
                    label: "Difficulty",
                    options: ["Easy", "Hard"],
                  },
                ],
              },
            ],
          },
        ],
      }),
    );
    expect(result.document.sections[0].items[0].type).toBe("row");
    expect(result.issues.some((issue) => issue.message.includes("unsupported row child type 'dropdown'"))).toBe(
      true,
    );
  });
});
