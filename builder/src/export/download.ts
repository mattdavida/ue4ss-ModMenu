import type { MenuDocument } from "../schema";

const encoder = new TextEncoder();

export function printJson(document: MenuDocument): string {
  return `${JSON.stringify(document, null, 2)}\n`;
}

export function downloadBytes(filename: string, bytes: Uint8Array, type: string) {
  const copy = new Uint8Array(bytes);
  const blob = new Blob([copy], { type });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export function downloadText(filename: string, text: string, type: string) {
  downloadBytes(filename, encoder.encode(text), type);
}

export async function copyText(text: string): Promise<void> {
  await navigator.clipboard.writeText(text);
}
