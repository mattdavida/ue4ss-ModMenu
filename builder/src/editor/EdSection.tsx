import type { ReactNode } from "react";

export function EdSection({
  title,
  open,
  onToggle,
  children,
}: {
  title: string;
  open: boolean;
  onToggle: () => void;
  children: ReactNode;
}) {
  return (
    <section className={`ed-panel${open ? "" : " is-collapsed"}`}>
      <button type="button" className="ed-panel-head" onClick={onToggle} aria-expanded={open}>
        <h2>{title}</h2>
        <span className="ed-panel-mark">{open ? "-" : "+"}</span>
      </button>
      {open && <div className="ed-panel-body">{children}</div>}
    </section>
  );
}
