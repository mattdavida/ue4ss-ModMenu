/** UE4SS `Key` names (docs.ue4ss.com). Toggle picker omits mouse / IME. Default is F6. */
export const DEFAULT_KEY = "F6";

export type KeyGroup = { label: string; keys: string[] };

export const KEY_GROUPS: KeyGroup[] = [
  {
    label: "Function",
    keys: ["F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"],
  },
  {
    label: "Letters",
    keys: "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split(""),
  },
  {
    label: "Number row",
    keys: ["ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE"],
  },
  {
    label: "Numpad",
    keys: [
      "NUM_ZERO",
      "NUM_ONE",
      "NUM_TWO",
      "NUM_THREE",
      "NUM_FOUR",
      "NUM_FIVE",
      "NUM_SIX",
      "NUM_SEVEN",
      "NUM_EIGHT",
      "NUM_NINE",
      "MULTIPLY",
      "ADD",
      "SUBTRACT",
      "DECIMAL",
      "DIVIDE",
      "NUM_LOCK",
    ],
  },
  {
    label: "Navigation",
    keys: [
      "ESCAPE",
      "TAB",
      "RETURN",
      "SPACE",
      "BACKSPACE",
      "INS",
      "DEL",
      "HOME",
      "END",
      "PAGE_UP",
      "PAGE_DOWN",
      "LEFT_ARROW",
      "UP_ARROW",
      "RIGHT_ARROW",
      "DOWN_ARROW",
    ],
  },
  {
    label: "Other",
    keys: [
      "PAUSE",
      "CAPS_LOCK",
      "SCROLL_LOCK",
      "PRINT_SCREEN",
      "LEFT_WIN",
      "RIGHT_WIN",
      "APPS",
      "OEM_PLUS",
      "OEM_MINUS",
      "OEM_COMMA",
      "OEM_PERIOD",
    ],
  },
];

export const TOGGLE_KEYS: string[] = KEY_GROUPS.flatMap((group) => group.keys);

export function isToggleKey(name: string): boolean {
  return TOGGLE_KEYS.includes(name);
}
