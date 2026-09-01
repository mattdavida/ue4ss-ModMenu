import type { ThemeName } from "../schema";
import { PANEL_PAD, PREVIEW_FONTS, THEME_KEYS, preset, type Color, type ThemeColors } from "./tokens";

export function colorCss(c: Color): string {
  const r = Math.round(c.R * 255);
  const g = Math.round(c.G * 255);
  const b = Math.round(c.B * 255);
  if (c.A >= 1) {
    return `rgb(${r}, ${g}, ${b})`;
  }
  return `rgba(${r}, ${g}, ${b}, ${c.A})`;
}

function kebab(key: string): string {
  return key.replace(/[A-Z]/g, (ch) => `-${ch.toLowerCase()}`);
}

export function themeVars(name: ThemeName): Record<string, string> {
  const colors: ThemeColors = preset(name);
  const pad = PANEL_PAD[name];
  const vars: Record<string, string> = {
    "--mm-pad-left": `${pad.left}px`,
    "--mm-pad-top": `${pad.top}px`,
    "--mm-pad-right": `${pad.right}px`,
    "--mm-pad-bottom": `${pad.bottom}px`,
    "--mm-font-title": `${PREVIEW_FONTS.title}px`,
    "--mm-font-hint": `${PREVIEW_FONTS.hint}px`,
    "--mm-font-item": `${PREVIEW_FONTS.item}px`,
    "--mm-font-section": `${PREVIEW_FONTS.section}px`,
    "--mm-font-dropdown": `${PREVIEW_FONTS.dropdown}px`,
  };
  for (const key of THEME_KEYS) {
    vars[`--mm-${kebab(key)}`] = colorCss(colors[key]);
  }
  return vars;
}
