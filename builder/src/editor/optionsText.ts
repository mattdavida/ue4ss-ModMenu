import type { DropdownOption } from "../schema";

export function formatOptions(options: DropdownOption[]): string {
  return options
    .map((opt) => {
      if (typeof opt === "string") {
        return opt;
      }
      if (opt.label !== undefined && opt.value !== undefined && opt.label !== opt.value) {
        return `${opt.label}|${opt.value}`;
      }
      return opt.label ?? opt.value ?? "";
    })
    .join("\n");
}

export function parseOptions(text: string): DropdownOption[] {
  const out: DropdownOption[] = [];
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (trimmed === "") {
      continue;
    }
    const bar = trimmed.indexOf("|");
    if (bar > 0) {
      const label = trimmed.slice(0, bar).trim();
      const value = trimmed.slice(bar + 1).trim();
      if (label && value) {
        out.push({ label, value });
        continue;
      }
    }
    out.push(trimmed);
  }
  return out;
}
