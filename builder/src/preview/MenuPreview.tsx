import { useEffect, useMemo, useState } from "react";
import type { ButtonItem, DockSide, MenuDocument, ThemeName } from "../schema";
import { themeVars } from "../theme";
import { buttonChrome } from "./chrome";
import { PreviewItem, type PreviewActions } from "./Items";
import "./MenuPreview.css";

const DOCK_OPTIONS: { label: string; value: DockSide }[] = [
  { label: "Top", value: "top" },
  { label: "Right", value: "right" },
  { label: "Bottom", value: "bottom" },
  { label: "Left", value: "left" },
];

function sectionTab(section: MenuDocument["sections"][number], tabs: string[] | undefined): string | undefined {
  if (!tabs || tabs.length === 0) {
    return undefined;
  }
  if (section.tab && tabs.includes(section.tab)) {
    return section.tab;
  }
  return tabs[0];
}

function seedFolds(doc: MenuDocument): Record<string, boolean> {
  const out: Record<string, boolean> = {};
  for (const section of doc.sections) {
    for (const item of section.items) {
      if (item.type === "fold") {
        out[`${section.id}.${item.id}`] = item.collapsed !== false;
      }
    }
  }
  return out;
}

function seedChecks(doc: MenuDocument): Record<string, boolean> {
  const out: Record<string, boolean> = {};
  const walk = (sectionId: string, items: MenuDocument["sections"][number]["items"]) => {
    for (const item of items) {
      if (item.type === "checkbox") {
        out[`${sectionId}.${item.id}`] = item.default === true;
      } else if (item.type === "row" || item.type === "fold") {
        walk(sectionId, item.items);
      }
    }
  };
  for (const section of doc.sections) {
    walk(section.id, section.items);
  }
  return out;
}

function seedCollapsed(doc: MenuDocument): Record<string, boolean> {
  const out: Record<string, boolean> = {};
  for (const section of doc.sections) {
    if (section.collapsible) {
      out[section.id] = section.collapsed === true;
    }
  }
  return out;
}

function ConfirmCard({ item, onDismiss }: { item: ButtonItem; onDismiss: () => void }) {
  const spec = item.confirm;
  if (!spec) {
    return null;
  }
  const ok = buttonChrome({ variant: spec.variant ?? item.variant ?? "danger" });
  const cancel = buttonChrome({ variant: "secondary" });
  return (
    <div className="mm-confirm-dim">
      <div className="mm-confirm-card">
        <div className="mm-confirm-pad">
          <p className="mm-confirm-title">{spec.title ?? "Are you sure?"}</p>
        </div>
        <div className="mm-confirm-rule" />
        {spec.message && (
          <>
            <div className="mm-confirm-pad">
              <p className="mm-confirm-msg">{spec.message}</p>
            </div>
            <div className="mm-confirm-rule" />
          </>
        )}
        <div className="mm-confirm-actions">
          <button type="button" className="mm-btn mm-btn-inline" style={cancel} onClick={onDismiss}>
            {spec.cancelLabel ?? "Cancel"}
          </button>
          <button type="button" className="mm-btn mm-btn-inline" style={ok} onClick={onDismiss}>
            {spec.confirmLabel ?? "Confirm"}
          </button>
        </div>
      </div>
    </div>
  );
}

export function MenuPreview({
  document,
  theme,
  onDockChange,
}: {
  document: MenuDocument;
  theme: ThemeName;
  onDockChange?: (dock: DockSide) => void;
}) {
  const tabs = document.init.tabs;
  const dock = document.init.dock;
  const [activeTab, setActiveTab] = useState(tabs?.[0] ?? null);
  const [collapsed, setCollapsed] = useState(() => seedCollapsed(document));
  const [foldCollapsed, setFoldCollapsed] = useState(() => seedFolds(document));
  const [checks, setChecks] = useState(() => seedChecks(document));
  const [openDropdown, setOpenDropdown] = useState<string | null>(null);
  const [dockOpen, setDockOpen] = useState(false);
  const [confirm, setConfirm] = useState<ButtonItem | null>(null);

  useEffect(() => {
    if (!tabs || tabs.length === 0) {
      setActiveTab(null);
      return;
    }
    setActiveTab((current) => (current && tabs.includes(current) ? current : tabs[0]));
  }, [tabs]);

  const visible = useMemo(() => {
    return document.sections.filter((section) => {
      if (!tabs || !activeTab) {
        return true;
      }
      return sectionTab(section, tabs) === activeTab;
    });
  }, [document.sections, tabs, activeTab]);

  const actions: PreviewActions = {
    openDropdown,
    setOpenDropdown: (key) => {
      setDockOpen(false);
      setOpenDropdown(key);
    },
    foldCollapsed,
    toggleFold: (key) => {
      setFoldCollapsed((prev) => ({ ...prev, [key]: !prev[key] }));
    },
    checks,
    toggleCheck: (key) => {
      setChecks((prev) => ({ ...prev, [key]: !prev[key] }));
    },
    onConfirm: (item) => {
      setConfirm(item);
    },
  };

  const dockLabel = DOCK_OPTIONS.find((opt) => opt.value === dock)?.label ?? dock;

  return (
    <div className={`mm-stage dock-${dock}`}>
      <div className="mm-panel" style={themeVars(theme)} data-theme={theme} role="region" aria-label="Menu preview">
        <div className="mm-scroll">
          <div className="mm-title-row">
            <h2 className="mm-title">{document.init.title}</h2>
            <button type="button" className="mm-btn mm-btn-inline mm-close" style={buttonChrome({})}>
              Close
            </button>
          </div>
          <p className="mm-hint">[{document.init.keyHint}] toggle menu</p>

          <p className="mm-hint mm-dock-cap">Dock</p>
          <div className="mm-drop">
            <button
              type="button"
              className="mm-drop-header"
              onClick={() => {
                setOpenDropdown(null);
                setDockOpen((open) => !open);
              }}
            >
              <span>{dockLabel}</span>
              <span className="mm-drop-arrow">{dockOpen ? "▲" : "▼"}</span>
            </button>
            {dockOpen && (
              <div className="mm-drop-list">
                {DOCK_OPTIONS.map((opt) => (
                  <button
                    key={opt.value}
                    type="button"
                    className={`mm-drop-opt${opt.value === dock ? " is-selected" : ""}`}
                    onClick={() => {
                      onDockChange?.(opt.value);
                      setDockOpen(false);
                    }}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>
            )}
          </div>

          {tabs && tabs.length > 0 && (
            <div className="mm-tabs">
              {tabs.map((name) => {
                const active = name === activeTab;
                const chrome = buttonChrome({ active });
                return (
                  <button
                    key={name}
                    type="button"
                    className="mm-tab"
                    style={chrome}
                    onClick={() => {
                      setActiveTab(name);
                      setOpenDropdown(null);
                      setDockOpen(false);
                    }}
                  >
                    {name}
                  </button>
                );
              })}
            </div>
          )}

          <div className="mm-head-pad" />

          {visible.length === 0 && <p className="mm-hint">No sections on this tab.</p>}

          {visible.map((section, sIndex) => {
            const isCollapsible = section.collapsible === true;
            const isCollapsed = isCollapsible && (collapsed[section.id] ?? section.collapsed === true);
            const title = section.title || section.id;
            return (
              <section key={section.id} className="mm-section">
                {isCollapsible ? (
                  <button
                    type="button"
                    className="mm-accordion mm-section-hdr"
                    onClick={() => {
                      setCollapsed((prev) => ({ ...prev, [section.id]: !prev[section.id] }));
                    }}
                  >
                    <span>{title}</span>
                    <span className="mm-mark">{isCollapsed ? "+" : "-"}</span>
                  </button>
                ) : (
                  <h3 className="mm-section-title">{title}</h3>
                )}
                {!isCollapsed && (
                  <div className="mm-section-body">
                    {section.items.map((item, index) => (
                      <PreviewItem
                        key={`${item.type}-${"id" in item ? item.id : index}`}
                        item={item}
                        sectionId={section.id}
                        actions={actions}
                        index={index}
                      />
                    ))}
                  </div>
                )}
                {sIndex < visible.length - 1 && <div className="mm-between" />}
              </section>
            );
          })}
          <div className="mm-foot" />
        </div>
        {confirm && (
          <ConfirmCard
            item={confirm}
            onDismiss={() => {
              setConfirm(null);
            }}
          />
        )}
      </div>
    </div>
  );
}
