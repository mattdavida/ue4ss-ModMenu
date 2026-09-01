import { useState, type ReactNode } from "react";
import type {
  ButtonItem,
  CheckboxItem,
  DropdownItem,
  FoldItem,
  Item,
  NumberItem,
  RowItem,
  TextInputItem,
} from "../schema";
import { buttonChrome } from "./chrome";
import { normalizeOptions, optionLabel } from "./options";

export type PreviewActions = {
  openDropdown: string | null;
  setOpenDropdown: (key: string | null) => void;
  foldCollapsed: Record<string, boolean>;
  toggleFold: (key: string) => void;
  checks: Record<string, boolean>;
  toggleCheck: (key: string) => void;
  onConfirm: (item: ButtonItem) => void;
};

function itemKey(sectionId: string, id: string | undefined, fallback: string): string {
  return `${sectionId}.${id ?? fallback}`;
}

function MmButton({
  item,
  fill,
  onClick,
}: {
  item: ButtonItem;
  fill?: boolean;
  onClick?: () => void;
}) {
  const chrome = buttonChrome(item);
  return (
    <button
      type="button"
      className={`mm-btn${fill === false ? " mm-btn-inline" : ""}`}
      style={chrome}
      disabled={item.enabled === false}
      onClick={onClick}
    >
      {item.label}
    </button>
  );
}

function MmCheckbox({
  item,
  valueKey,
  actions,
}: {
  item: CheckboxItem;
  valueKey: string;
  actions: PreviewActions;
}) {
  const on = actions.checks[valueKey] ?? item.default === true;
  return (
    <label className="mm-check">
      <input
        type="checkbox"
        checked={on}
        onChange={() => {
          actions.toggleCheck(valueKey);
        }}
      />
      <span>
        {item.label}: {on ? "ON" : "OFF"}
      </span>
    </label>
  );
}

function MmField({
  label,
  labelWidth,
  fieldWidth,
  fill,
  children,
}: {
  label: string;
  labelWidth?: number;
  fieldWidth?: number;
  fill?: boolean;
  children: ReactNode;
}) {
  return (
    <div className={`mm-field${fill ? " mm-field-fill" : ""}`}>
      <span className="mm-field-label" style={labelWidth ? { width: labelWidth, flex: "0 0 auto" } : undefined}>
        {label}
      </span>
      <span className="mm-field-box" style={fieldWidth ? { width: fieldWidth, flex: "0 0 auto" } : undefined}>
        {children}
      </span>
    </div>
  );
}

function MmNumber({ item, fill }: { item: NumberItem; fill?: boolean }) {
  const width = item.fieldWidth ?? (fill === false ? 72 : 96);
  return (
    <MmField label={item.label} labelWidth={item.labelWidth} fieldWidth={width} fill={fill !== false}>
      <input
        className="mm-edit"
        type="text"
        defaultValue={item.default ?? 0}
        placeholder={item.placeholder}
        readOnly
      />
    </MmField>
  );
}

function MmText({ item, fill }: { item: TextInputItem; fill?: boolean }) {
  const width = item.fieldWidth ?? (fill === false ? 72 : undefined);
  return (
    <MmField label={item.label} labelWidth={item.labelWidth} fieldWidth={width} fill={fill !== false}>
      <input className="mm-edit" type="text" defaultValue={item.default ?? ""} placeholder={item.placeholder} readOnly />
    </MmField>
  );
}

function MmDropdown({
  item,
  dropKey,
  actions,
}: {
  item: DropdownItem;
  dropKey: string;
  actions: PreviewActions;
}) {
  const [filter, setFilter] = useState("");
  const open = actions.openDropdown === dropKey;
  const list = normalizeOptions(item.options);
  const placeholder = item.placeholder ?? "Select...";
  const selected = optionLabel(item.options, item.default, placeholder);
  const maxVisible = item.maxVisible ?? (item.searchable ? 400 : list.length);
  const matched = list.filter((opt) => opt.label.toLowerCase().includes(filter.toLowerCase()));
  const shown = matched.slice(0, maxVisible);
  const extra = matched.length - shown.length;

  return (
    <div className="mm-drop">
      <button
        type="button"
        className="mm-drop-header"
        onClick={() => {
          actions.setOpenDropdown(open ? null : dropKey);
          setFilter("");
        }}
      >
        <span>{selected}</span>
        <span className="mm-drop-arrow">{open ? "▲" : "▼"}</span>
      </button>
      {open && (
        <div className="mm-drop-list" style={item.listMaxHeight ? { maxHeight: item.listMaxHeight } : undefined}>
          {item.searchable && (
            <input
              className="mm-drop-search"
              type="text"
              value={filter}
              placeholder="Type to filter..."
              onChange={(event) => {
                setFilter(event.target.value);
              }}
            />
          )}
          {shown.map((opt) => (
            <div
              key={opt.value}
              className={`mm-drop-opt${opt.value === item.default ? " is-selected" : ""}`}
            >
              {opt.label}
            </div>
          ))}
          {extra > 0 && <div className="mm-drop-more">…{extra} more — type to narrow</div>}
          {matched.length === 0 && <div className="mm-drop-more">No matches</div>}
        </div>
      )}
    </div>
  );
}

function MmFold({
  item,
  sectionId,
  actions,
}: {
  item: FoldItem;
  sectionId: string;
  actions: PreviewActions;
}) {
  const key = `${sectionId}.${item.id}`;
  const collapsed = actions.foldCollapsed[key] ?? item.collapsed !== false;
  return (
    <div className="mm-fold">
      <button
        type="button"
        className="mm-accordion"
        onClick={() => {
          actions.toggleFold(key);
        }}
      >
        <span>{item.label}</span>
        <span className="mm-mark">{collapsed ? "+" : "-"}</span>
      </button>
      {!collapsed && (
        <div className="mm-fold-body">
          {item.items.map((child, index) => (
            <PreviewItem
              key={`${child.type}-${"id" in child ? child.id : index}`}
              item={child}
              sectionId={sectionId}
              actions={actions}
              index={index}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function MmRow({
  item,
  sectionId,
  actions,
}: {
  item: RowItem;
  sectionId: string;
  actions: PreviewActions;
}) {
  return (
    <div className="mm-row">
      {item.items.map((child, index) => (
        <PreviewItem
          key={`${child.type}-${"id" in child ? child.id : index}`}
          item={child}
          sectionId={sectionId}
          actions={actions}
          index={index}
          layout="horizontal"
        />
      ))}
    </div>
  );
}

export function PreviewItem({
  item,
  sectionId,
  actions,
  index,
  layout = "vertical",
}: {
  item: Item;
  sectionId: string;
  actions: PreviewActions;
  index: number;
  layout?: "vertical" | "horizontal";
}) {
  const horizontal = layout === "horizontal";
  if (item.type === "separator") {
    return <div className="mm-sep" />;
  }
  if (item.type === "label") {
    if (item.label.trim() === "") {
      return null;
    }
    return <p className="mm-label">{item.label}</p>;
  }
  if (item.type === "button") {
    return (
      <MmButton
        item={item}
        fill={!horizontal}
        onClick={() => {
          if (item.confirm) {
            actions.onConfirm(item);
          }
        }}
      />
    );
  }
  if (item.type === "checkbox") {
    return <MmCheckbox item={item} valueKey={itemKey(sectionId, item.id, String(index))} actions={actions} />;
  }
  if (item.type === "number") {
    return <MmNumber item={item} fill={!horizontal} />;
  }
  if (item.type === "textinput") {
    return <MmText item={item} fill={!horizontal} />;
  }
  if (item.type === "dropdown") {
    return <MmDropdown item={item} dropKey={itemKey(sectionId, item.id, String(index))} actions={actions} />;
  }
  if (item.type === "row") {
    return <MmRow item={item} sectionId={sectionId} actions={actions} />;
  }
  if (item.type === "fold") {
    return <MmFold item={item} sectionId={sectionId} actions={actions} />;
  }
  return null;
}
