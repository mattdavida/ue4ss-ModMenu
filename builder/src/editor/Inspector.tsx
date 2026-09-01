import type { ReactNode } from "react";
import type {
  ButtonItem,
  ButtonVariant,
  CheckboxItem,
  DockSide,
  DropdownItem,
  FoldItem,
  Item,
  MenuDocument,
  NumberItem,
  Section,
  TextInputItem,
  ThemeName,
} from "../schema";
import { BUTTON_VARIANTS, DOCK_SIDES, KEY_GROUPS, THEMES, isToggleKey, validateDocument } from "../schema";
import type { NodeRef } from "./model";
import { canMove, getItem, idCollision } from "./model";
import { formatOptions, parseOptions } from "./optionsText";

const VARIANTS = [...BUTTON_VARIANTS] as ButtonVariant[];

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="ed-field">
      <span>{label}</span>
      {children}
    </label>
  );
}

function Text({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <Field label={label}>
      <input
        type="text"
        value={value}
        onChange={(event) => {
          onChange(event.target.value);
        }}
      />
    </Field>
  );
}

function Toggle({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (value: boolean) => void;
}) {
  return (
    <label className="ed-check">
      <input
        type="checkbox"
        checked={checked}
        onChange={(event) => {
          onChange(event.target.checked);
        }}
      />
      {label}
    </label>
  );
}

function InitFields({
  document,
  onPatchInit,
}: {
  document: MenuDocument;
  onPatchInit: (patch: Partial<MenuDocument["init"]>) => void;
}) {
  const init = document.init;
  return (
    <>
      <Text label="Title" value={init.title} onChange={(title) => onPatchInit({ title })} />
      <Text label="Instance id" value={init.instanceId} onChange={(instanceId) => onPatchInit({ instanceId })} />
      <Field label="Toggle key">
        <select
          value={init.keyHint}
          onChange={(event) => {
            onPatchInit({ keyHint: event.target.value });
          }}
        >
          {!isToggleKey(init.keyHint) && <option value={init.keyHint}>{init.keyHint}</option>}
          {KEY_GROUPS.map((group) => (
            <optgroup key={group.label} label={group.label}>
              {group.keys.map((name) => (
                <option key={name} value={name}>
                  {name}
                </option>
              ))}
            </optgroup>
          ))}
        </select>
      </Field>
      <Field label="Dock">
        <select
          value={init.dock}
          onChange={(event) => {
            onPatchInit({ dock: event.target.value as DockSide });
          }}
        >
          {[...DOCK_SIDES].map((side) => (
            <option key={side} value={side}>
              {side}
            </option>
          ))}
        </select>
      </Field>
      <Field label="Theme">
        <select
          value={init.theme}
          onChange={(event) => {
            onPatchInit({ theme: event.target.value as ThemeName });
          }}
        >
          {[...THEMES].map((name) => (
            <option key={name} value={name}>
              {name}
            </option>
          ))}
        </select>
      </Field>
    </>
  );
}

function TabFields({
  name,
  onRename,
}: {
  name: string;
  onRename: (name: string) => void;
}) {
  return <Text label="Name" value={name} onChange={onRename} />;
}

function SectionFields({
  section,
  tabs,
  onPatch,
}: {
  section: Section;
  tabs?: string[];
  onPatch: (patch: Partial<Section>) => void;
}) {
  return (
    <>
      <Text label="Id" value={section.id} onChange={(id) => onPatch({ id })} />
      <Text label="Title" value={section.title ?? ""} onChange={(title) => onPatch({ title })} />
      {tabs && tabs.length > 0 && (
        <Field label="Tab">
          <select
            value={section.tab ?? ""}
            onChange={(event) => {
              onPatch({ tab: event.target.value });
            }}
          >
            <option value="">First tab</option>
            {tabs.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </select>
        </Field>
      )}
      <Toggle
        label="Collapsible"
        checked={section.collapsible === true}
        onChange={(collapsible) => {
          onPatch({ collapsible, collapsed: collapsible ? section.collapsed === true : undefined });
        }}
      />
      <Toggle
        label="Start collapsed"
        checked={section.collapsed === true}
        onChange={(collapsed) => {
          onPatch({ collapsed, collapsible: collapsed ? true : section.collapsible });
        }}
      />
    </>
  );
}

function IdField({
  item,
  section,
  path,
  onPatch,
}: {
  item: { id?: string; label?: string };
  section: Section;
  path: number[];
  onPatch: (patch: Record<string, unknown>) => void;
}) {
  const id = item.id ?? "";
  const clash = idCollision(section, id, path);
  return (
    <>
      <Text
        label="Id"
        value={id}
        onChange={(next) => {
          onPatch({ id: next });
        }}
      />
      <p className="ed-muted">Auto from section + label if you leave this blank.</p>
      {clash && <p className="ed-warn">This id is already used in the section.</p>}
    </>
  );
}

function ItemFields({
  item,
  section,
  path,
  onPatch,
}: {
  item: Item;
  section: Section;
  path: number[];
  onPatch: (patch: Record<string, unknown>) => void;
}) {
  if (item.type === "separator") {
    return <p className="ed-muted">No fields.</p>;
  }
  if (item.type === "row") {
    return <p className="ed-muted">Row children are in the outline. Add button, checkbox, label, number, or text.</p>;
  }
  if (item.type === "label") {
    return (
      <>
        <Text label="Label" value={item.label} onChange={(label) => onPatch({ label })} />
        <IdField item={item} section={section} path={path} onPatch={onPatch} />
      </>
    );
  }
  if (item.type === "fold") {
    const fold = item as FoldItem;
    return (
      <>
        <IdField item={fold} section={section} path={path} onPatch={onPatch} />
        <Text label="Label" value={fold.label} onChange={(label) => onPatch({ label })} />
        <Toggle label="Start collapsed" checked={fold.collapsed !== false} onChange={(collapsed) => onPatch({ collapsed })} />
      </>
    );
  }
  if (item.type === "button") {
    const button = item as ButtonItem;
    return (
      <>
        <IdField item={button} section={section} path={path} onPatch={onPatch} />
        <Text label="Label" value={button.label} onChange={(label) => onPatch({ label })} />
        <Field label="Variant">
          <select
            value={button.variant ?? "default"}
            onChange={(event) => {
              onPatch({ variant: event.target.value as ButtonVariant });
            }}
          >
            {VARIANTS.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </select>
        </Field>
        <Toggle label="Enabled" checked={button.enabled !== false} onChange={(enabled) => onPatch({ enabled })} />
        <Toggle label="Active" checked={button.active === true} onChange={(active) => onPatch({ active })} />
        <Toggle
          label="Confirm first"
          checked={button.confirm !== undefined}
          onChange={(on) => {
            onPatch({
              confirm: on
                ? {
                    title: button.confirm?.title ?? "Are you sure?",
                    message: button.confirm?.message ?? "",
                    confirmLabel: button.confirm?.confirmLabel ?? "Confirm",
                  }
                : null,
            });
          }}
        />
        {button.confirm && (
          <>
            <Text
              label="Confirm title"
              value={button.confirm.title ?? ""}
              onChange={(title) => onPatch({ confirm: { ...button.confirm, title } })}
            />
            <Text
              label="Confirm message"
              value={button.confirm.message ?? ""}
              onChange={(message) => onPatch({ confirm: { ...button.confirm, message } })}
            />
            <Text
              label="Confirm label"
              value={button.confirm.confirmLabel ?? "Confirm"}
              onChange={(confirmLabel) => onPatch({ confirm: { ...button.confirm, confirmLabel } })}
            />
          </>
        )}
      </>
    );
  }
  if (item.type === "checkbox") {
    const box = item as CheckboxItem;
    return (
      <>
        <IdField item={box} section={section} path={path} onPatch={onPatch} />
        <Text label="Label" value={box.label} onChange={(label) => onPatch({ label })} />
        <Toggle label="Default on" checked={box.default === true} onChange={(value) => onPatch({ default: value })} />
      </>
    );
  }
  if (item.type === "dropdown") {
    const drop = item as DropdownItem;
    return (
      <>
        <IdField item={drop} section={section} path={path} onPatch={onPatch} />
        <Text label="Label" value={drop.label} onChange={(label) => onPatch({ label })} />
        <Field label="Options (one per line, or label|value)">
          <textarea
            rows={5}
            value={formatOptions(drop.options)}
            onChange={(event) => {
              const options = parseOptions(event.target.value);
              onPatch({ options: options.length > 0 ? options : drop.options });
            }}
          />
        </Field>
        <Text label="Default" value={drop.default ?? ""} onChange={(value) => onPatch({ default: value || null })} />
        <Text
          label="Placeholder"
          value={drop.placeholder ?? ""}
          onChange={(placeholder) => onPatch({ placeholder: placeholder || undefined })}
        />
        <Toggle label="Searchable" checked={drop.searchable === true} onChange={(searchable) => onPatch({ searchable })} />
      </>
    );
  }
  if (item.type === "number") {
    const num = item as NumberItem;
    return (
      <>
        <IdField item={num} section={section} path={path} onPatch={onPatch} />
        <Text label="Label" value={num.label} onChange={(label) => onPatch({ label })} />
        <Text
          label="Default"
          value={String(num.default ?? "")}
          onChange={(value) => onPatch({ default: value === "" ? undefined : Number(value) })}
        />
        <Text
          label="Min"
          value={num.min === undefined ? "" : String(num.min)}
          onChange={(value) => onPatch({ min: value === "" ? undefined : Number(value) })}
        />
        <Text
          label="Max"
          value={num.max === undefined ? "" : String(num.max)}
          onChange={(value) => onPatch({ max: value === "" ? undefined : Number(value) })}
        />
        <Toggle label="Integer" checked={num.integer === true} onChange={(integer) => onPatch({ integer })} />
      </>
    );
  }
  if (item.type === "textinput") {
    const text = item as TextInputItem;
    return (
      <>
        <IdField item={text} section={section} path={path} onPatch={onPatch} />
        <Text label="Label" value={text.label} onChange={(label) => onPatch({ label })} />
        <Text label="Default" value={text.default ?? ""} onChange={(value) => onPatch({ default: value })} />
        <Text
          label="Placeholder"
          value={text.placeholder ?? ""}
          onChange={(placeholder) => onPatch({ placeholder: placeholder || undefined })}
        />
      </>
    );
  }
  return null;
}

export function Inspector({
  document,
  selection,
  onPatchInit,
  onRenameTab,
  onPatchSection,
  onPatchItem,
  onMove,
  onRemove,
}: {
  document: MenuDocument;
  selection: NodeRef | null;
  onPatchInit: (patch: Partial<MenuDocument["init"]>) => void;
  onRenameTab: (index: number, name: string) => void;
  onPatchSection: (index: number, patch: Partial<Section>) => void;
  onPatchItem: (sel: Extract<NodeRef, { kind: "item" }>, patch: Record<string, unknown>) => void;
  onMove: (delta: -1 | 1) => void;
  onRemove: () => void;
}) {
  const issues = validateDocument(document);
  const canDelete = selection !== null && selection.kind !== "init";
  return (
    <>
      {selection && selection.kind !== "init" && (
        <div className="ed-ops">
          <button type="button" disabled={!canMove(document, selection, -1)} onClick={() => onMove(-1)}>
            Up
          </button>
          <button type="button" disabled={!canMove(document, selection, 1)} onClick={() => onMove(1)}>
            Down
          </button>
          <button type="button" disabled={!canDelete} onClick={onRemove}>
            Remove
          </button>
        </div>
      )}
      {selection === null && <p className="ed-muted">Select something in the outline.</p>}
      {selection?.kind === "init" && <InitFields document={document} onPatchInit={onPatchInit} />}
      {selection?.kind === "tab" && document.init.tabs && (
        <TabFields name={document.init.tabs[selection.index] ?? ""} onRename={(name) => onRenameTab(selection.index, name)} />
      )}
      {selection?.kind === "section" && document.sections[selection.index] && (
        <SectionFields
          section={document.sections[selection.index]}
          tabs={document.init.tabs}
          onPatch={(patch) => onPatchSection(selection.index, patch)}
        />
      )}
      {selection?.kind === "item" && (() => {
        const item = getItem(document, selection);
        const section = document.sections[selection.sectionIndex];
        if (!item || !section) {
          return <p className="ed-muted">Missing item.</p>;
        }
        return <ItemFields item={item} section={section} path={selection.path} onPatch={(patch) => onPatchItem(selection, patch)} />;
      })()}
      {issues.length > 0 && (
        <ul className="ed-issues">
          {issues.slice(0, 6).map((issue) => (
            <li key={`${issue.path}:${issue.message}`}>
              {issue.path}: {issue.message}
            </li>
          ))}
        </ul>
      )}
    </>
  );
}
