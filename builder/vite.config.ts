/// <reference types="vitest/config" />
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";
import { embedModMenuRuntime } from "./vite-plugin-runtime.ts";

/** Project Pages URL is `/<repo>/`. Local / e2e keep `/`. */
function pagesBase(raw: string | undefined): string {
  const value = raw?.trim();
  if (!value) {
    return "/";
  }
  const lead = value.startsWith("/") ? value : `/${value}`;
  return lead.endsWith("/") ? lead : `${lead}/`;
}

export default defineConfig({
  base: pagesBase(process.env.GITHUB_PAGES_BASE),
  plugins: [react(), embedModMenuRuntime()],
  test: {
    environment: "node",
    exclude: ["e2e/**", "node_modules/**", "dist/**"],
  },
});


