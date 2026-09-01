import type { Item, MenuDocument, Section } from "../schema";
import type { NodeRef } from "./model";
import { sameRef } from "./model";

function Row({
  label,
  hint,
  depth,
  selected,
  onSelect,
  onRemove,
}: {
  label: string;
  hint?: string;
  depth: number;
  selected: boolean;
  onSelect: () => void;
  onRemove?: () => void;
}) {
  return (
    <div className={`ed-tree-row${selected ? " is-selected" : ""}`} style={{ paddingLeft: 8 + depth * 12 }}>
      <button type="button" className="ed-tree-label" onClick={onSelect}>
        <span>{label}</span>
        {hint && <span className="ed-tree-hint">{hint}</span>}
      </button>
      {onRemove && (
        <button type="button" className="ed-tree-x" aria-label={`Remove ${label}`} title="Remove" onClick={onRemove}>
          ×
        </button>
      )}
    </div>
  );
}

function itemLabel(item: Item): string {
  if (item.type === "separator") {
    return "separator";
  }
  if (item.type === "row") {
    return "row";
  }
  return item.label;
}

function ItemBranch({
  items,
  sectionIndex,
  pathPrefix,
  selection,
  onSelect,
  onRemove,
}: {
  items: Item[];
  sectionIndex: number;
  pathPrefix: number[];
  selection: NodeRef | null;
  onSelect: (ref: NodeRef) => void;
  onRemove: (ref: NodeRef) => void;
}) {
  return (
    <>
      {items.map((item, index) => {
        const path = [...pathPrefix, index];
        const ref: NodeRef = { kind: "item", sectionIndex, path };
        const children = item.type === "row" || item.type === "fold" ? item.items : null;
        return (
          <div key={`${item.type}-${path.join(".")}`}>
            <Row
              label={itemLabel(item)}
              hint={item.type}
              depth={2 + pathPrefix.length}
              selected={sameRef(selection, ref)}
              onSelect={() => {
                onSelect(ref);
              }}
              onRemove={() => {
                onRemove(ref);
              }}
            />
            {children && (
              <ItemBranch
                items={children as Item[]}
                sectionIndex={sectionIndex}
                pathPrefix={path}
                selection={selection}
                onSelect={onSelect}
                onRemove={onRemove}
              />
            )}
          </div>
        );
      })}
    </>
  );
}

function sectionHint(section: Section, tabs?: string[]): string | undefined {
  if (!tabs || tabs.length === 0) {
    return undefined;
  }
  return section.tab && tabs.includes(section.tab) ? section.tab : tabs[0];
}

export function Tree({
  document,
  selection,
  onSelect,
  onRemove,
}: {
  document: MenuDocument;
  selection: NodeRef | null;
  onSelect: (ref: NodeRef) => void;
  onRemove: (ref: NodeRef) => void;
}) {
  const tabs = document.init.tabs;
  const initRef: NodeRef = { kind: "init" };
  return (
    <div aria-label="Outline">
      <Row
        label={document.init.title || "Menu"}
        hint="init"
        depth={0}
        selected={sameRef(selection, initRef)}
        onSelect={() => {
          onSelect(initRef);
        }}
      />
      {tabs && tabs.length > 0 && (
        <>
          <p className="ed-tree-group">Tabs</p>
          {tabs.map((name, index) => {
            const ref: NodeRef = { kind: "tab", index };
            return (
              <Row
                key={`${name}-${index}`}
                label={name}
                hint="tab"
                depth={1}
                selected={sameRef(selection, ref)}
                onSelect={() => {
                  onSelect(ref);
                }}
                onRemove={() => {
                  onRemove(ref);
                }}
              />
            );
          })}
        </>
      )}
      <p className="ed-tree-group">Sections</p>
      {document.sections.length === 0 && <p className="ed-empty">No sections.</p>}
      {document.sections.map((section, index) => {
        const ref: NodeRef = { kind: "section", index };
        return (
          <div key={`${section.id}-${index}`}>
            <Row
              label={section.title || section.id}
              hint={sectionHint(section, tabs)}
              depth={1}
              selected={sameRef(selection, ref)}
              onSelect={() => {
                onSelect(ref);
              }}
              onRemove={() => {
                onRemove(ref);
              }}
            />
            {section.items.length === 0 && <p className="ed-empty ed-empty-indent">Empty section.</p>}
            <ItemBranch
              items={section.items}
              sectionIndex={index}
              pathPrefix={[]}
              selection={selection}
              onSelect={onSelect}
              onRemove={onRemove}
            />
          </div>
        );
      })}
    </div>
  );
}
