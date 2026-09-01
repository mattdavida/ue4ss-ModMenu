import { MODMENU_BUNDLE } from "virtual:modmenu-runtime";
import type { MenuDocument } from "../schema";
import { hostFolderName, printLua } from "./lua";
import { zipStore } from "./zip";

const encoder = new TextEncoder();

export function hostZip(document: MenuDocument): { filename: string; bytes: Uint8Array } {
  const folder = hostFolderName(document);
  const lua = printLua(document);
  const bytes = zipStore([
    { path: `${folder}/enabled.txt`, data: encoder.encode("") },
    { path: `${folder}/Scripts/main.lua`, data: encoder.encode(lua) },
    { path: "shared/ModMenu/ModMenu.lua", data: encoder.encode(MODMENU_BUNDLE) },
  ]);
  return { filename: `${folder}.zip`, bytes };
}
