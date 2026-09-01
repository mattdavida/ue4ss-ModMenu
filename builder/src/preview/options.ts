import type { DropdownOption } from "../schema";

export type NormalizedOption = { label: string; value: string };

export function normalizeOptions(options: DropdownOption[]): NormalizedOption[] {
  const out: NormalizedOption[] = [];
  for (const opt of options) {
    if (typeof opt === "string") {
      out.push({ label: opt, value: opt });
      continue;
    }
    const label = opt.label ?? opt.value;
    const value = opt.value ?? opt.label;
    if (label === undefined && value === undefined) {
      continue;
    }
    out.push({ label: String(label ?? value), value: String(value ?? label) });
  }
  return out;
}

export function optionLabel(options: DropdownOption[], value: string | null | undefined, placeholder: string): string {
  if (value == null || value === "") {
    return placeholder;
  }
  const found = normalizeOptions(options).find((opt) => opt.value === value);
  return found?.label ?? placeholder;
}
