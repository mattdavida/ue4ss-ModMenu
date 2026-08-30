/**
 * Pack ModMenu into a single package.preload release file.
 *
 * Usage: npm run bundle
 * Output: dist/ModMenu.bundle.lua
 *
 * Install for players as: Mods/shared/ModMenu/ModMenu.lua
 * Hosts keep: require("ModMenu.ModMenu")
 * UEHelpers is left as an external require (not bundled).
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const OUT = path.join(ROOT, "dist", "ModMenu.bundle.lua");
const ENTRY = "ModMenu.lua";

const EXTERNAL_OK = new Set(["UEHelpers.UEHelpers"]);
const REQUIRE_RE = /require\s*\(\s*["']([^"']+)["']\s*\)/g;

function readLua(relPath) {
  const abs = path.join(ROOT, relPath);
  if (!fs.existsSync(abs)) {
    throw new Error(`Missing source: ${relPath}`);
  }
  return fs.readFileSync(abs, "utf8").replace(/^\uFEFF/, "");
}

function collectRequires(source) {
  const names = new Set();
  for (const match of source.matchAll(REQUIRE_RE)) {
    const name = match[1];
    // Skip doc placeholders like require("ModMenu.widgets.<type>")
    if (!/^[A-Za-z_][A-Za-z0-9_.]*$/.test(name)) continue;
    names.add(name);
  }
  return names;
}

/** dir/*.lua — peers A–Z, init.lua last so it can require the others. */
function discoverPackageModules(dir, prefix) {
  const abs = path.join(ROOT, dir);
  const files = fs
    .readdirSync(abs, { withFileTypes: true })
    .filter((ent) => ent.isFile() && ent.name.endsWith(".lua"))
    .map((ent) => ent.name);

  const typeFiles = files.filter((name) => name !== "init.lua").sort();
  const ordered = [...typeFiles];
  if (files.includes("init.lua")) {
    ordered.push("init.lua");
  }

  if (files.includes("init.lua")) {
    const initRequires = collectRequires(readLua(`${dir}/init.lua`));
    for (const file of typeFiles) {
      const modName = `${prefix}.${path.basename(file, ".lua")}`;
      if (!initRequires.has(modName)) {
        console.warn(`${dir}/${file} is not required by ${dir}/init.lua`);
      }
    }
  }

  return ordered.map((file) => [
    `${prefix}.${path.basename(file, ".lua")}`,
    `${dir}/${file}`,
  ]);
}

/** @type {[string, string][]} moduleName → relative path (deps only; entry is free chunk) */
const MODULES = [
  ...discoverPackageModules("store", "ModMenu.store"),
  ["ModMenu.core.store", "core/store.lua"],
  ["ModMenu.ConfigManager", "ConfigManager.lua"],
  ["ModMenu.core.util", "core/util.lua"],
  ["ModMenu.core.theme", "core/theme.lua"],
  ["ModMenu.core.umg", "core/umg.lua"],
  ["ModMenu.core.shared", "core/shared.lua"],
  ["ModMenu.core.config", "core/config.lua"],
  ["ModMenu.core.instance", "core/instance.lua"],
  ["ModMenu.core.inputmode", "core/inputmode.lua"],
  ["ModMenu.core.cursor", "core/cursor.lua"],
  ["ModMenu.core.input", "core/input.lua"],
  ["ModMenu.core.options", "core/options.lua"],
  ["ModMenu.core.dockmath", "core/dockmath.lua"],
  ...discoverPackageModules("widgets", "ModMenu.widgets"),
  ["ModMenu.shell.session", "shell/session.lua"],
  ["ModMenu.shell.dock", "shell/dock.lua"],
  ["ModMenu.shell.close", "shell/close.lua"],
  ["ModMenu.shell.collapse", "shell/collapse.lua"],
  ["ModMenu.shell.tabs", "shell/tabs.lua"],
  ["ModMenu.shell.confirm", "shell/confirm.lua"],
  ["ModMenu.shell.build", "shell/build.lua"],
  ["ModMenu.shell.lifecycle", "shell/lifecycle.lua"],
  ["ModMenu.shell.registry", "shell/registry.lua"],
];

function luaString(s) {
  return `"${s.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

function wrapPreload(name, source) {
  const body = source.replace(/\s*$/, "");
  return `package.preload[${luaString(name)}] = function(...)\n${body}\nend\n`;
}

function main() {
  const known = new Set(MODULES.map(([name]) => name));
  const chunks = [];
  const allSources = [];

  chunks.push(`--[[
  ModMenu.bundle.lua — generated release bundle. Do not edit.

  Build: npm run bundle
  Install as: Mods/shared/ModMenu/ModMenu.lua
  Hosts: require("ModMenu.ModMenu")
]]
`);

  for (const [name, relPath] of MODULES) {
    const source = readLua(relPath);
    allSources.push({ name, relPath, source });
    chunks.push(`-- ${relPath}\n`);
    chunks.push(wrapPreload(name, source));
    chunks.push("\n");
  }

  const entrySource = readLua(ENTRY);
  allSources.push({ name: "ModMenu.ModMenu", relPath: ENTRY, source: entrySource });

  for (const { name, relPath, source } of allSources) {
    for (const req of collectRequires(source)) {
      if (EXTERNAL_OK.has(req)) continue;
      if (req.startsWith("ModMenu.")) {
        if (!known.has(req) && req !== "ModMenu.ModMenu") {
          throw new Error(
            `${relPath}: require(${JSON.stringify(req)}) is not in the bundle module list`
          );
        }
        continue;
      }
      throw new Error(
        `${relPath}: unexpected require(${JSON.stringify(req)}) — add to EXTERNAL_OK or MODULES`
      );
    }
  }

  // Entry is the free chunk so UE4SS loading ModMenu.ModMenu executes/returns it.
  chunks.push(`-- ${ENTRY} (entry)\n`);
  chunks.push(entrySource.replace(/\s*$/, ""));
  chunks.push("\n");

  const bundled = chunks.join("");
  if (/package\.preload\s*\[\s*["']UEHelpers/.test(bundled)) {
    throw new Error("Bundle must not preload UEHelpers");
  }

  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  fs.writeFileSync(OUT, bundled, "utf8");

  const kb = (Buffer.byteLength(bundled, "utf8") / 1024).toFixed(1);
  console.log(`Wrote ${path.relative(ROOT, OUT)} (${MODULES.length} modules + entry, ${kb} KiB)`);
}

try {
  main();
} catch (err) {
  console.error(`bundle failed: ${err.message}`);
  process.exit(1);
}
