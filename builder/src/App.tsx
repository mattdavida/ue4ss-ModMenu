import { useEffect, useRef, useState } from "react";
import {
  ConfirmDialog,
  EdSection,
  Inspector,
  Palette,
  Tree,
  adoptJson,
  bootDocument,
  saveStored,
} from "./editor";
import type { ConfirmCopy } from "./editor";
import {
  addItem,
  addSection,
  addTab,
  canMove,
  ensureIds,
  moveNode,
  movedRef,
  patchInit,
  patchItem,
  patchSection,
  removeNode,
  renameTab,
  type NodeRef,
} from "./editor/model";
import { ExportBar } from "./export/ExportBar";
import { MenuPreview } from "./preview";
import { countItems, emptyDocument, hostFixture, validateDocument } from "./schema";
import type { DockSide, ItemType, MenuDocument, ThemeName } from "./schema";
import "./App.css";
import "./editor/Editor.css";

const REPLACE: Record<"new" | "example" | "open", ConfirmCopy> = {
  new: {
    title: "New menu",
    message: "This replaces the menu you have open. The new menu will autosave.",
    confirmLabel: "New menu",
  },
  example: {
    title: "Load example",
    message: "This replaces the menu you have open with the ModMenu Host example.",
    confirmLabel: "Load example",
  },
  open: {
    title: "Open JSON",
    message: "Choose a builder JSON file. That menu will replace what you have open.",
    confirmLabel: "Choose file",
  },
};

function App() {
  const [doc, setDoc] = useState<MenuDocument>(bootDocument);
  const [selection, setSelection] = useState<NodeRef>(() =>
    doc.sections.length > 0 ? { kind: "section", index: 0 } : { kind: "init" },
  );
  const [theme, setTheme] = useState<ThemeName>(doc.init.theme);
  const [previewKey, setPreviewKey] = useState(0);
  const [openError, setOpenError] = useState<string | null>(null);
  const [replace, setReplace] = useState<keyof typeof REPLACE | null>(null);
  const [openPanels, setOpenPanels] = useState({ palette: true, outline: true, inspector: true });
  const openInputRef = useRef<HTMLInputElement>(null);
  const replaceRef = useRef<keyof typeof REPLACE | null>(null);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      saveStored(doc);
    }, 300);
    return () => {
      window.clearTimeout(timer);
    };
  }, [doc]);

  const togglePanel = (key: keyof typeof openPanels) => {
    setOpenPanels((prev) => ({ ...prev, [key]: !prev[key] }));
  };

  const removeAt = (ref: NodeRef) => {
    const result = removeNode(doc, ref);
    setDoc(result.doc);
    setSelection(result.selection);
  };

  const issues = validateDocument(doc);
  const ok = issues.length === 0;

  const load = (next: MenuDocument) => {
    const ready = ensureIds(next);
    setOpenError(null);
    setDoc(ready);
    setTheme(ready.init.theme);
    setSelection(ready.sections.length > 0 ? { kind: "section", index: 0 } : { kind: "init" });
    setPreviewKey((n) => n + 1);
    saveStored(ready);
  };

  const openFromText = (text: string) => {
    const result = adoptJson(text);
    if (!result.ok) {
      setOpenError(result.reason);
      return;
    }
    load(result.document);
  };

  const askReplace = (kind: keyof typeof REPLACE) => {
    replaceRef.current = kind;
    setReplace(kind);
  };

  const finishReplace = (ok: boolean) => {
    const kind = replaceRef.current;
    replaceRef.current = null;
    setReplace(null);
    if (!ok || kind === null) {
      return;
    }
    if (kind === "new") {
      load(emptyDocument());
      return;
    }
    if (kind === "example") {
      load(structuredClone(hostFixture));
      return;
    }
    openInputRef.current?.click();
  };

  return (
    <div className="app">
      <header className="bar">
        <div>
          <p className="kicker">ModMenu</p>
          <h1>Builder</h1>
        </div>
        <div className="bar-meta">
          <p className={ok ? "ok" : "bad"}>
            {ok
              ? `${doc.sections.length} sections · ${countItems(doc)} items`
              : `${issues.length} schema issues`}
          </p>
          {openError ? (
            <p className="bad" role="alert">
              {openError}
            </p>
          ) : null}
          <div className="bar-actions" role="group" aria-label="Document">
            <button
              type="button"
              onClick={() => {
                askReplace("new");
              }}
            >
              New
            </button>
            <button
              type="button"
              onClick={() => {
                askReplace("example");
              }}
            >
              Example
            </button>
            <button
              type="button"
              title="Open a builder JSON file"
              onClick={() => {
                askReplace("open");
              }}
            >
              Open
            </button>
            <input
              ref={openInputRef}
              type="file"
              accept="application/json,.json"
              aria-label="Open JSON file"
              hidden
              onChange={(event) => {
                const file = event.target.files?.[0];
                event.target.value = "";
                if (!file) {
                  return;
                }
                void file.text().then(openFromText, () => {
                  setOpenError("could not read file");
                });
              }}
            />
          </div>
          <ExportBar document={doc} />
          <div className="theme-toggle" role="group" aria-label="Preview theme">
            <button
              type="button"
              className={theme === "light" ? "is-on" : undefined}
              onClick={() => {
                setTheme("light");
              }}
            >
              Light
            </button>
            <button
              type="button"
              className={theme === "dark" ? "is-on" : undefined}
              onClick={() => {
                setTheme("dark");
              }}
            >
              Dark
            </button>
          </div>
        </div>
      </header>
      <ConfirmDialog
        open={replace !== null}
        title={replace ? REPLACE[replace].title : ""}
        message={replace ? REPLACE[replace].message : ""}
        confirmLabel={replace ? REPLACE[replace].confirmLabel : "Replace"}
        onConfirm={() => {
          finishReplace(true);
        }}
        onCancel={() => {
          finishReplace(false);
        }}
      />
      <div className="app-body">
        <aside className="ed-sidebar">
          <EdSection title="Palette" open={openPanels.palette} onToggle={() => togglePanel("palette")}>
            <Palette
              document={doc}
              selection={selection}
              onAddShell={(kind) => {
                const result = kind === "tab" ? addTab(doc) : addSection(doc, selection);
                setDoc(result.doc);
                setSelection(result.selection);
              }}
              onAddWidget={(type: ItemType) => {
                const result = addItem(doc, selection, type);
                if (!result) {
                  return;
                }
                setDoc(result.doc);
                setSelection(result.selection);
              }}
            />
          </EdSection>
          <EdSection title="Outline" open={openPanels.outline} onToggle={() => togglePanel("outline")}>
            <Tree document={doc} selection={selection} onSelect={setSelection} onRemove={removeAt} />
          </EdSection>
          <EdSection title="Inspector" open={openPanels.inspector} onToggle={() => togglePanel("inspector")}>
            <Inspector
              document={doc}
            selection={selection}
            onPatchInit={(patch) => {
                setDoc(patchInit(doc, patch));
                if (patch.theme) {
                  setTheme(patch.theme);
                }
              }}
              onRenameTab={(index, name) => {
                setDoc(renameTab(doc, index, name));
              }}
              onPatchSection={(index, patch) => {
                setDoc(patchSection(doc, index, patch));
              }}
              onPatchItem={(sel, patch) => {
                setDoc(patchItem(doc, sel, patch));
              }}
              onMove={(delta) => {
                if (!canMove(doc, selection, delta)) {
                  return;
                }
                setDoc(moveNode(doc, selection, delta));
                setSelection(movedRef(selection, delta));
              }}
              onRemove={() => {
                removeAt(selection);
              }}
            />
          </EdSection>
        </aside>
        <MenuPreview
          key={previewKey}
          document={doc}
          theme={theme}
          onDockChange={(dock: DockSide) => {
            setDoc(patchInit(doc, { dock }));
          }}
        />
      </div>
    </div>
  );
}

export default App;
