/**
 * Build a player-ready ModMenu zip (no rename required).
 *
 * Usage: npm run deploy
 *
 * Outputs:
 *   dist/ModMenu.bundle.lua              — raw bundle artifact
 *   dist/release/shared/ModMenu/ModMenu.lua
 *   dist/ModMenu.zip                     — extract into ue4ss/Mods/
 */

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const DIST = path.join(ROOT, "dist");
const BUNDLE = path.join(DIST, "ModMenu.bundle.lua");
const RELEASE_ROOT = path.join(DIST, "release");
const INSTALL_LUA = path.join(RELEASE_ROOT, "shared", "ModMenu", "ModMenu.lua");
const ZIP = path.join(DIST, "ModMenu.zip");

function run(cmd, args, opts = {}) {
  const result = spawnSync(cmd, args, { stdio: "inherit", ...opts });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    throw new Error(`${cmd} ${args.join(" ")} exited with ${result.status}`);
  }
}

function zipRelease() {
  fs.rmSync(ZIP, { force: true });

  if (process.platform === "win32") {
    // Compress contents of release/ so the zip root is shared/...
    const ps = [
      "Compress-Archive",
      "-Path",
      path.join(RELEASE_ROOT, "*"),
      "-DestinationPath",
      ZIP,
      "-Force",
    ];
    run("powershell", ["-NoProfile", "-Command", ps.join(" ")]);
    return;
  }

  run("zip", ["-r", ZIP, "."], { cwd: RELEASE_ROOT });
}

function main() {
  run(process.execPath, [path.join(ROOT, "tools", "bundle.mjs")], { cwd: ROOT });

  if (!fs.existsSync(BUNDLE)) {
    throw new Error(`Bundle missing after build: ${BUNDLE}`);
  }

  fs.rmSync(RELEASE_ROOT, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(INSTALL_LUA), { recursive: true });
  fs.copyFileSync(BUNDLE, INSTALL_LUA);

  zipRelease();

  const kb = (fs.statSync(ZIP).size / 1024).toFixed(1);
  console.log(`Wrote ${path.relative(ROOT, INSTALL_LUA)}`);
  console.log(`Wrote ${path.relative(ROOT, ZIP)} (${kb} KiB)`);
  console.log("Extract ModMenu.zip into ue4ss/Mods/ (creates shared/ModMenu/ModMenu.lua)");
}

try {
  main();
} catch (err) {
  console.error(`deploy failed: ${err.message}`);
  process.exit(1);
}
