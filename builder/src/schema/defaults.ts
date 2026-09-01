import { DOCUMENT_VERSION } from "./types";
import type { MenuDocument } from "./types";

export function emptyDocument(): MenuDocument {
  return {
    version: DOCUMENT_VERSION,
    init: {
      title: "My Mod Menu",
      instanceId: "MyMod",
      keyHint: "F6",
      dock: "right",
      theme: "dark",
    },
    sections: [
      {
        id: "Main",
        title: "Main",
        items: [{ type: "label", label: "Add widgets from the palette." }],
      },
    ],
  };
}
