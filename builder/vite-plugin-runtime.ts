import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { Plugin } from "vite";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BUNDLE_LUA = path.join(ROOT, "dist", "ModMenu.bundle.lua");
const BUNDLE_SCRIPT = path.join(ROOT, "tools", "bundle.mjs");

export const RUNTIME_ID = "virtual:modmenu-runtime";

let cached: string | undefined;

function ensureBundle(): string {
  if (cached !== undefined) {
    return cached;
  }
  execFileSync(process.execPath, [BUNDLE_SCRIPT], { cwd: ROOT, stdio: "pipe" });
  cached = fs.readFileSync(BUNDLE_LUA, "utf8");
  return cached;
}

export function embedModMenuRuntime(): Plugin {
  return {
    name: "embed-modmenu-runtime",
    resolveId(id) {
      if (id === RUNTIME_ID) {
        return id;
      }
    },
    load(id) {
      if (id !== RUNTIME_ID) {
        return;
      }
      return `export const MODMENU_BUNDLE = ${JSON.stringify(ensureBundle())};\n`;
    },
  };
}
