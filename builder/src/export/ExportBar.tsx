import { useState } from "react";
import type { MenuDocument } from "../schema";
import { copyText, downloadBytes, downloadText, printJson, printLua } from "./index";

export function ExportBar({ document }: { document: MenuDocument }) {
  const [copied, setCopied] = useState<"lua" | "json" | null>(null);

  const flash = (kind: "lua" | "json") => {
    setCopied(kind);
    window.setTimeout(() => {
      setCopied((current) => (current === kind ? null : current));
    }, 1600);
  };

  return (
    <div className="bar-actions" role="group" aria-label="Export">
      <button
        type="button"
        title="ue4ss/Mods zip: your menu + shared/ModMenu"
        onClick={() => {
          void import("./hostZip").then(({ hostZip }) => {
            const { filename, bytes } = hostZip(document);
            downloadBytes(filename, bytes, "application/zip");
          });
        }}
      >
        Export zip
      </button>
      <button
        type="button"
        onClick={() => {
          void copyText(printLua(document)).then(() => {
            flash("lua");
          });
        }}
      >
        {copied === "lua" ? "Copied Lua" : "Copy Lua"}
      </button>
      <button
        type="button"
        onClick={() => {
          downloadText("modmenu.json", printJson(document), "application/json");
        }}
      >
        JSON
      </button>
    </div>
  );
}
