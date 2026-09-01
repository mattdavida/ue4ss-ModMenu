import type { ButtonVariant } from "../schema";

const VARIANT_VARS: Record<string, { bg: string; fg: string }> = {
  primary: { bg: "var(--mm-button-bg-primary)", fg: "var(--mm-button-text-primary)" },
  secondary: { bg: "var(--mm-button-bg-secondary)", fg: "var(--mm-button-text-secondary)" },
  success: { bg: "var(--mm-button-bg-success)", fg: "var(--mm-button-text-success)" },
  danger: { bg: "var(--mm-button-bg-danger)", fg: "var(--mm-button-text-danger)" },
  warning: { bg: "var(--mm-button-bg-warning)", fg: "var(--mm-button-text-warning)" },
  info: { bg: "var(--mm-button-bg-info)", fg: "var(--mm-button-text-info)" },
};

export function resolveVariant(variant: ButtonVariant | undefined): string {
  if (variant === "accent") {
    return "primary";
  }
  return variant ?? "default";
}

/** Paint order matches widgets/button.lua: disabled, then active, then variant. */
export function buttonChrome(opts: {
  variant?: ButtonVariant;
  enabled?: boolean;
  active?: boolean;
}): { background: string; color: string } {
  if (opts.enabled === false) {
    return { background: "var(--mm-button-bg-disabled)", color: "var(--mm-button-text-disabled)" };
  }
  if (opts.active === true) {
    return { background: "var(--mm-button-bg-active)", color: "var(--mm-button-text-active)" };
  }
  const key = resolveVariant(opts.variant);
  const pair = VARIANT_VARS[key];
  if (pair) {
    return { background: pair.bg, color: pair.fg };
  }
  return { background: "var(--mm-button-bg)", color: "var(--mm-button-text)" };
}
