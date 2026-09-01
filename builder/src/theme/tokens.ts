import type { ThemeName } from "../schema";

/** Same 0–1 RGB as core/theme.lua. */
export type Color = { R: number; G: number; B: number; A: number };

function C(r: number, g: number, b: number, a = 1): Color {
  return { R: r, G: g, B: b, A: a };
}

export const THEME_KEYS = [
  "panelBg",
  "panelBorder",
  "textPrimary",
  "textMuted",
  "textAccent",
  "textStatus",
  "buttonBg",
  "buttonText",
  "buttonBgPrimary",
  "buttonTextPrimary",
  "buttonBgSecondary",
  "buttonTextSecondary",
  "buttonBgSuccess",
  "buttonTextSuccess",
  "buttonBgDanger",
  "buttonTextDanger",
  "buttonBgWarning",
  "buttonTextWarning",
  "buttonBgInfo",
  "buttonTextInfo",
  "buttonBgActive",
  "buttonTextActive",
  "buttonBgDisabled",
  "buttonTextDisabled",
  "sectionHeaderBg",
  "sectionMark",
  "fieldBg",
  "fieldText",
  "fieldHint",
  "dropdownHeaderBg",
  "dropdownHeaderText",
  "dropdownOptionBg",
  "dropdownOptionText",
  "dropdownMore",
  "overlayDim",
  "confirmCardBg",
  "confirmDivider",
] as const;

export type ThemeKey = (typeof THEME_KEYS)[number];
export type ThemeColors = Record<ThemeKey, Color>;

export const LIGHT: ThemeColors = {
  panelBg: C(0.05, 0.07, 0.12, 0.92),
  panelBorder: C(0.05, 0.07, 0.12, 0.92),
  textPrimary: C(0.95, 0.95, 0.98),
  textMuted: C(0.72, 0.76, 0.82),
  textAccent: C(0.45, 0.72, 0.88),
  textStatus: C(0.83, 0.69, 0.22),
  buttonBg: C(0.18, 0.22, 0.32),
  buttonText: C(0.95, 0.95, 0.98),
  buttonBgPrimary: C(0.05, 0.43, 0.99),
  buttonTextPrimary: C(1.0, 1.0, 1.0),
  buttonBgSecondary: C(0.42, 0.46, 0.49),
  buttonTextSecondary: C(1.0, 1.0, 1.0),
  buttonBgSuccess: C(0.1, 0.53, 0.33),
  buttonTextSuccess: C(1.0, 1.0, 1.0),
  buttonBgDanger: C(0.86, 0.21, 0.27),
  buttonTextDanger: C(1.0, 1.0, 1.0),
  buttonBgWarning: C(1.0, 0.76, 0.03),
  buttonTextWarning: C(0.08, 0.09, 0.1),
  buttonBgInfo: C(0.05, 0.79, 0.94),
  buttonTextInfo: C(0.08, 0.09, 0.1),
  buttonBgActive: C(0.12, 0.4, 0.28),
  buttonTextActive: C(0.82, 0.98, 0.88),
  buttonBgDisabled: C(0.12, 0.14, 0.18),
  buttonTextDisabled: C(0.45, 0.48, 0.52),
  sectionHeaderBg: C(0.1, 0.13, 0.2),
  sectionMark: C(0.72, 0.76, 0.82),
  fieldBg: C(0.88, 0.9, 0.94),
  fieldText: C(0.06, 0.07, 0.1),
  fieldHint: C(0.35, 0.38, 0.45),
  dropdownHeaderBg: C(0.22, 0.28, 0.4),
  dropdownHeaderText: C(0.98, 0.98, 1.0),
  dropdownOptionBg: C(0.88, 0.9, 0.94),
  dropdownOptionText: C(0.06, 0.07, 0.1),
  dropdownMore: C(0.7, 0.75, 0.85),
  overlayDim: C(0.02, 0.03, 0.05, 0.62),
  confirmCardBg: C(0.08, 0.1, 0.16, 0.98),
  confirmDivider: C(0.22, 0.26, 0.34, 1.0),
};

export const DARK: ThemeColors = {
  panelBg: C(0.11, 0.11, 0.12, 0.9),
  panelBorder: C(0.62, 0.62, 0.64, 0.9),
  textPrimary: C(0.92, 0.92, 0.93),
  textMuted: C(0.62, 0.62, 0.64),
  textAccent: C(0.12, 0.72, 0.7),
  textStatus: C(0.83, 0.69, 0.22),
  buttonBg: C(0.2, 0.2, 0.21),
  buttonText: C(0.92, 0.92, 0.93),
  buttonBgPrimary: C(0.08, 0.34, 0.78),
  buttonTextPrimary: C(1.0, 1.0, 1.0),
  buttonBgSecondary: C(0.32, 0.32, 0.34),
  buttonTextSecondary: C(0.92, 0.92, 0.93),
  buttonBgSuccess: C(0.08, 0.42, 0.28),
  buttonTextSuccess: C(0.92, 0.98, 0.94),
  buttonBgDanger: C(0.72, 0.18, 0.22),
  buttonTextDanger: C(1.0, 1.0, 1.0),
  buttonBgWarning: C(0.9, 0.68, 0.1),
  buttonTextWarning: C(0.1, 0.09, 0.06),
  buttonBgInfo: C(0.08, 0.52, 0.58),
  buttonTextInfo: C(0.9, 0.98, 0.98),
  buttonBgActive: C(0.1, 0.36, 0.28),
  buttonTextActive: C(0.72, 0.95, 0.84),
  buttonBgDisabled: C(0.14, 0.14, 0.15),
  buttonTextDisabled: C(0.4, 0.4, 0.42),
  sectionHeaderBg: C(0.16, 0.16, 0.17),
  sectionMark: C(0.62, 0.62, 0.64),
  fieldBg: C(0.06, 0.06, 0.07),
  fieldText: C(0.94, 0.94, 0.94),
  fieldHint: C(0.5, 0.5, 0.52),
  dropdownHeaderBg: C(0.2, 0.2, 0.21),
  dropdownHeaderText: C(0.92, 0.92, 0.93),
  dropdownOptionBg: C(0.08, 0.08, 0.09),
  dropdownOptionText: C(0.92, 0.92, 0.93),
  dropdownMore: C(0.62, 0.62, 0.64),
  overlayDim: C(0.04, 0.04, 0.05, 0.62),
  confirmCardBg: C(0.16, 0.16, 0.17, 0.98),
  confirmDivider: C(0.3, 0.3, 0.32, 1.0),
};

export const PANEL_PAD = {
  light: { left: 20, top: 18, right: 20, bottom: 18 },
  dark: { left: 16, top: 14, right: 16, bottom: 14 },
} as const;

/** Dense desktop look (Host dummy / hero shots), not raw UMG default 22/16. */
export const PREVIEW_FONTS = {
  title: 16,
  hint: 12,
  item: 13,
  section: 14,
  dropdown: 13,
} as const;

export function preset(name: ThemeName): ThemeColors {
  return name === "dark" ? DARK : LIGHT;
}
