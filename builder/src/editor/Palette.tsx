import type { ItemType } from "../schema";
import type { NodeRef } from "./model";
import { addTarget } from "./model";
import type { MenuDocument } from "../schema";

const SHELL = [
  { id: "tab" as const, label: "Tab" },
  { id: "section" as const, label: "Section" },
];

const WIDGETS: { id: ItemType; label: string }[] = [
  { id: "label", label: "Label" },
  { id: "separator", label: "Separator" },
  { id: "button", label: "Button" },
  { id: "checkbox", label: "Checkbox" },
  { id: "dropdown", label: "Dropdown" },
  { id: "number", label: "Number" },
  { id: "textinput", label: "Text" },
  { id: "row", label: "Row" },
  { id: "fold", label: "Fold" },
];

export function Palette({
  document,
  selection,
  onAddShell,
  onAddWidget,
}: {
  document: MenuDocument;
  selection: NodeRef | null;
  onAddShell: (kind: "tab" | "section") => void;
  onAddWidget: (type: ItemType) => void;
}) {
  return (
    <>
      <div className="ed-chips">
        {SHELL.map((item) => (
          <button key={item.id} type="button" onClick={() => onAddShell(item.id)}>
            {item.label}
          </button>
        ))}
      </div>
      <div className="ed-chips">
        {WIDGETS.map((item) => {
          const allowed = addTarget(document, selection, item.id) !== null;
          return (
            <button
              key={item.id}
              type="button"
              disabled={!allowed}
              title={allowed ? `Add ${item.label}` : "Not allowed on the selected parent"}
              onClick={() => {
                onAddWidget(item.id);
              }}
            >
              {item.label}
            </button>
          );
        })}
      </div>
    </>
  );
}
