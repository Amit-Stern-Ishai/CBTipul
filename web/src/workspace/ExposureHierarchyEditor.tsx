import { useEffect, useRef, useState } from "react";
import { ArrowUp, ArrowDown, GripVertical, Plus, Trash2 } from "lucide-react";
import { useWrite } from "../ui/hooks";
import { DirtyGuard } from "../ui/shared";
import { ApiError } from "../data/api";
import {
  emptyExposure,
  exposureRequest,
  moveExposure,
  validExposure,
  type ExposureDocument,
  type ExposureRecord,
} from "../data/exposureHierarchy";
import "./exposure-hierarchy.css";
export function ExposureHierarchyEditor({
  patient,
  shared = false,
  onDraftState,
}: {
  patient: string;
  shared?: boolean;
  onDraftState?: (value: { dirty: boolean; busy: boolean }) => void;
}) {
  const write = useWrite(),
    alive = useRef(true),
    pending = useRef(false),
    drag = useRef<string | null>(null);
  const [record, setRecord] = useState<ExposureRecord | null>(null),
    [draft, setDraft] = useState(emptyExposure),
    [backup, setBackup] = useState<ExposureDocument | null>(null),
    [loaded, setLoaded] = useState(false),
    [editing, setEditing] = useState(false),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(""),
    [message, setMessage] = useState(""),
    [conflict, setConflict] = useState(false);
  const dirty =
    loaded &&
    JSON.stringify(draft) !==
      JSON.stringify(record?.document ?? emptyExposure());
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);
  useEffect(() => {
    onDraftState?.({ dirty, busy });
    return () => onDraftState?.({ dirty: false, busy: false });
  }, [dirty, busy, onDraftState]);
  async function run(action: "load" | "save") {
    if (pending.current) return;
    pending.current = true;
    setBusy(true);
    setError("");
    setMessage("");
    try {
      const result = await exposureRequest(
        action,
        patient,
        record?.revision ?? null,
        draft,
      );
      if (!alive.current) return;
      setRecord(result);
      setDraft(result.document ?? emptyExposure());
      setLoaded(true);
      setEditing(action === "load" && result.document === null && write);
      setConflict(false);
      if (action === "save") setMessage("המדרג נשמר");
    } catch (e) {
      if (!alive.current) return;
      const code = e instanceof ApiError ? e.code : "";
      setConflict(code === "revision_conflict");
      setError(
        code === "revision_conflict"
          ? "המדרג השתנה במכשיר אחר. השינויים שלכם נשארו כאן."
          : code === "access"
            ? "אין כרגע הרשאה למדרג. אפשר לבדוק שוב."
            : "לא ניתן לאשר שהפעולה הושלמה. השינויים נשארו כאן. אפשר לנסות שוב.",
      );
    } finally {
      pending.current = false;
      if (alive.current) setBusy(false);
    }
  }
  useEffect(() => {
    void run("load");
  }, []);
  function reload() {
    if (dirty) {
      if (!confirm("לטעון את המדרג העדכני? השינויים שלכם יישמרו כאן בנפרד."))
        return;
      setBackup(structuredClone(draft));
    }
    void run("load");
  }
  function move(id: string, to: number) {
    setDraft((d) => moveExposure(d, id, to));
    setMessage("המיקום עודכן. יש לשמור את השינויים.");
  }
  function update(
    id: string,
    change: { situation?: string; difficulty?: number | null },
  ) {
    setDraft((d) => ({
      items: d.items.map((x) => (x.id === id ? { ...x, ...change } : x)),
    }));
  }
  return (
    <section
      className="exposure-editor"
      dir="rtl"
      aria-label="מדרג חשיפות"
      aria-busy={busy}
    >
      {!shared && <DirtyGuard dirty={dirty} busy={busy} />}
      <header className={editing ? "exposure-edit-header" : undefined}>
        <h2>מדרג חשיפות</h2>
        {loaded && editing && (
          <div className="exposure-actions">
            <button
              className="secondary"
              disabled={busy}
              onClick={() => {
                if (!dirty || confirm("יש שינויים שלא נשמרו. לוותר עליהם?")) {
                  setDraft(record?.document ?? emptyExposure());
                  setEditing(false);
                  setError("");
                  setConflict(false);
                }
              }}
            >
              ביטול עריכה
            </button>
            <button
              disabled={busy || !write || conflict || !validExposure(draft)}
              onClick={() => void run("save")}
            >
              שמירה
            </button>
          </div>
        )}
        {loaded && !editing && write && (
          <button
            className="secondary"
            onClick={() => setEditing(true)}
            disabled={busy}
          >
            עריכה
          </button>
        )}
      </header>
      {busy && <p role="status">{loaded ? "שומר…" : "טוענים מדרג…"}</p>}
      {error && (
        <div role="alert">
          <p>{error}</p>
          <button className="secondary" onClick={reload} disabled={busy}>
            {conflict ? "טעינת המדרג העדכני" : "ניסיון טעינה נוסף"}
          </button>
        </div>
      )}
      {backup && (
        <button
          className="secondary"
          disabled={busy}
          onClick={() => {
            if (!dirty || confirm("להחזיר את השינויים הקודמים לעריכה?")) {
              setDraft(backup);
              setBackup(null);
              setEditing(true);
            }
          }}
        >
          חזרה לשינויים שלי
        </button>
      )}
      {loaded && (
        <>
          <p className="muted">
            {editing
              ? "גררו את הידית כדי לשנות סדר, או השתמשו בחצים."
              : "לפי הסדר שבחרתם"}
          </p>
          {!draft.items.length && !editing && <p>אין עדיין מצבים במדרג.</p>}
          <ol className="exposure-list">
            {draft.items.map((item, index) => (
              <li
                key={item.id}
                onDragOver={(e) => {
                  if (editing && !busy && drag.current) e.preventDefault();
                }}
                onDrop={(e) => {
                  e.preventDefault();
                  if (editing && !busy && drag.current)
                    move(drag.current, index);
                  drag.current = null;
                }}
              >
                <span className="exposure-position">{index + 1}</span>
                {editing ? (
                  <>
                    <div className="exposure-content">
                      <label>
                        המצב
                        <textarea
                          value={item.situation}
                          rows={2}
                          disabled={busy}
                          onChange={(e) =>
                            update(item.id, { situation: e.target.value })
                          }
                        />
                      </label>
                      <label className="exposure-rating">
                        רמת הקושי{" "}
                        <output>
                          {item.difficulty === null
                            ? "טרם דורג"
                            : `${item.difficulty}%`}
                        </output>
                        <input
                          type="range"
                          min={0}
                          max={100}
                          step={1}
                          value={item.difficulty ?? 50}
                          disabled={busy}
                          aria-valuetext={
                            item.difficulty === null
                              ? "טרם דורג"
                              : `${item.difficulty}%`
                          }
                          onChange={(e) =>
                            update(item.id, {
                              difficulty: Number(e.target.value),
                            })
                          }
                        />
                      </label>
                      <button
                        className="secondary"
                        disabled={busy || item.difficulty === null}
                        onClick={() => update(item.id, { difficulty: null })}
                      >
                        ניקוי דירוג
                      </button>
                    </div>
                    <div className="exposure-controls">
                      <button
                        className="secondary exposure-handle"
                        draggable={!busy}
                        disabled={busy}
                        aria-label={`גרירת מצב ${index + 1}`}
                        onDragStart={(e) => {
                          drag.current = item.id;
                          e.dataTransfer.effectAllowed = "move";
                          e.dataTransfer.setData("text/plain", item.id);
                        }}
                        onDragEnd={() => {
                          drag.current = null;
                        }}
                      >
                        <GripVertical size={20} />
                      </button>
                      <button
                        className="secondary"
                        disabled={busy || index === 0}
                        aria-label={`הזזת מצב ${index + 1} למעלה`}
                        onClick={() => move(item.id, index - 1)}
                      >
                        <ArrowUp size={18} />
                      </button>
                      <button
                        className="secondary"
                        disabled={busy || index === draft.items.length - 1}
                        aria-label={`הזזת מצב ${index + 1} למטה`}
                        onClick={() => move(item.id, index + 1)}
                      >
                        <ArrowDown size={18} />
                      </button>
                      <button
                        className="secondary"
                        disabled={busy}
                        aria-label={`מחיקת מצב ${index + 1}`}
                        onClick={() =>
                          setDraft((d) => ({
                            items: d.items.filter((x) => x.id !== item.id),
                          }))
                        }
                      >
                        <Trash2 size={18} />
                      </button>
                    </div>
                  </>
                ) : (
                  <>
                    <p className="exposure-content" dir="auto">
                      {item.situation}
                    </p>
                    <strong className="exposure-score">
                      {item.difficulty === null
                        ? "טרם דורג"
                        : `${item.difficulty}%`}
                    </strong>
                  </>
                )}
              </li>
            ))}
          </ol>
          {editing && (
            <>
              <button
                className="secondary"
                disabled={busy || draft.items.length >= 100}
                onClick={() =>
                  setDraft((d) => ({
                    items: [
                      ...d.items,
                      {
                        id: crypto.randomUUID(),
                        situation: "",
                        difficulty: null,
                      },
                    ],
                  }))
                }
              >
                <Plus size={18} />
                הוספת מצב
              </button>

              {!validExposure(draft) && (
                <p>יש לכתוב מצב בכל שורה (עד 1,000 תווים).</p>
              )}
            </>
          )}
          <p role="status">{message}</p>
        </>
      )}
    </section>
  );
}
