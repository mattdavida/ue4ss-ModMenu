import { useEffect, useRef } from "react";

export type ConfirmCopy = {
  title: string;
  message: string;
  confirmLabel: string;
};

export function ConfirmDialog({
  open,
  title,
  message,
  confirmLabel,
  onConfirm,
  onCancel,
}: ConfirmCopy & {
  open: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  const ref = useRef<HTMLDialogElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) {
      return;
    }
    if (open) {
      if (!el.open) {
        el.showModal();
      }
      return;
    }
    if (el.open) {
      el.close();
    }
  }, [open]);

  return (
    <dialog
      ref={ref}
      className="app-dialog"
      aria-labelledby="app-dialog-title"
      onCancel={(event) => {
        event.preventDefault();
        onCancel();
      }}
      onClick={(event) => {
        if (event.target === event.currentTarget) {
          onCancel();
        }
      }}
    >
      <form
        className="app-dialog-card"
        onSubmit={(event) => {
          event.preventDefault();
          onConfirm();
        }}
      >
        <div className="app-dialog-body">
          <p className="kicker">Builder</p>
          <h2 id="app-dialog-title">{title}</h2>
          <p>{message}</p>
        </div>
        <div className="app-dialog-actions">
          <button type="button" autoFocus onClick={onCancel}>
            Cancel
          </button>
          <button type="submit" className="app-dialog-go">
            {confirmLabel}
          </button>
        </div>
      </form>
    </dialog>
  );
}
