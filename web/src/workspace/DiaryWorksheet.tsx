import {
  useEffect,
  useId,
  useRef,
  useState,
  type ReactNode,
  type TextareaHTMLAttributes,
} from "react";
import { Plus, Trash2, X } from "lucide-react";
import mobile from "../mobile-he.json";
import { he } from "../he";
import { ww } from "./he";
import { thinkingErrors, updateItem, type Worksheet } from "./model";
import vocabulary from "./feeling-vocabulary.json";

type Row = Record<string, unknown>;
const rows = (value: unknown) => (Array.isArray(value) ? (value as Row[]) : []);

/** Grow with content and width changes, without changing the controlled clinical value. */
function GrowingText(props: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  const ref = useRef<HTMLTextAreaElement>(null);
  useEffect(() => {
    const area = ref.current;
    if (!area) return;
    let width = 0;
    const grow = () => {
      area.style.height = "auto";
      area.style.height = `${area.scrollHeight + 2}px`;
    };
    grow();
    const observer = new ResizeObserver(() => {
      if (area.clientWidth !== width) {
        width = area.clientWidth;
        grow();
      }
    });
    observer.observe(area);
    return () => observer.disconnect();
  }, [props.value]);
  return <textarea {...props} ref={ref} rows={3} maxLength={50000} />;
}
function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="ww-sheet ww-diary-section" aria-label={title}>
      <h2>{title}</h2>
      {children}
    </section>
  );
}
function Rating({
  title,
  label,
  value,
  disabled,
  onChange,
}: {
  title: string;
  label?: string;
  value: unknown;
  disabled: boolean;
  onChange: (value: number | null) => void;
}) {
  const id = useId();
  const current = typeof value === "number" ? value : null;
  return (
    <div className="ww-rating">
      <div className="ww-rating-label">
        <label htmlFor={id}>{label ?? title}</label>
        <input
          id={id}
          aria-label={`${title} — אחוז`}
          type="number"
          min={0}
          max={100}
          step={1}
          disabled={disabled}
          value={current ?? ""}
          placeholder="—"
          onChange={(e) =>
            onChange(e.target.value === "" ? null : Number(e.target.value))
          }
        />
        <span aria-hidden="true">%</span>
      </div>
      {current === null ? (
        <div className="ww-rating-choices" aria-label={title}>
          {[0, 25, 50, 75, 100].map((n) => (
            <button
              type="button"
              className="secondary"
              disabled={disabled}
              key={n}
              aria-label={`${title}: ${n}%`}
              onClick={() => onChange(n)}
            >
              {n}%
            </button>
          ))}
        </div>
      ) : (
        <input
          aria-label={`${title} — מחוון`}
          type="range"
          min={0}
          max={100}
          step={1}
          value={current}
          disabled={disabled}
          onChange={(e) => onChange(Number(e.target.value))}
        />
      )}
    </div>
  );
}
function FeelingPicker({
  values,
  third,
  disabled,
  onChange,
}: {
  values: Row[];
  third: boolean;
  disabled: boolean;
  onChange: (rows: Row[]) => void;
}) {
  const id = useId();
  const picker = useRef<HTMLDivElement>(null);
  const search = useRef<HTMLInputElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const [query, setQuery] = useState("");
  const [custom, setCustom] = useState("");
  const [customOpen, setCustomOpen] = useState(false);
  const [error, setError] = useState("");
  const selected = new Set(values.map((row) => String(row.name ?? "").trim()));
  const close = () => {
    picker.current?.hidePopover();
    trigger.current?.focus();
  };
  useEffect(() => {
    if (disabled) picker.current?.hidePopover();
  }, [disabled]);
  const pick = (name: string) => {
    const trimmed = name.trim();
    if (!trimmed) {
      setError("יש להזין שם לרגש.");
      return;
    }
    if (selected.has(trimmed)) {
      setError("הרגש הזה כבר נבחר.");
      return;
    }
    // Mobile picker metadata never enters the response payload. Replace legacy blank placeholders only on explicit selection.
    const next = values.filter((row) => String(row.name ?? "").trim());
    onChange([
      ...next,
      third
        ? { name: trimmed, intensityBefore: null, intensityAfter: null }
        : { name: trimmed, intensity: 80 },
    ]);
    close();
  };
  const needle = query.trim();
  return (
    <>
      <button
        ref={trigger}
        type="button"
        className="secondary ww-feeling-add"
        disabled={disabled || values.length >= 100}
        popoverTarget={id}
      >
        <Plus size={16} />
        הוספת רגש
      </button>
      <div
        id={id}
        ref={picker}
        popover="auto"
        className="ww-feeling-picker"
        dir="rtl"
        onToggle={(e) => {
          if (e.newState === "open") {
            setQuery("");
            setError("");
            setCustomOpen(false);
            search.current?.focus();
          }
        }}
      >
        <div className="ww-picker-head">
          <h2>בחירת רגש</h2>
          <button
            type="button"
            className="ww-text-button"
            aria-label="סגירת בחירת רגש"
            onClick={close}
          >
            <X size={20} />
          </button>
        </div>
        <p className="ww-quiet">
          בחרו רגש כדי להוסיף אותו. אפשר להוסיף רגשות נוספים בהמשך.
        </p>
        <label htmlFor={`${id}-search`}>חיפוש רגש</label>
        <input
          ref={search}
          id={`${id}-search`}
          value={query}
          maxLength={100}
          disabled={disabled}
          onChange={(e) => setQuery(e.target.value)}
        />
        <div className="ww-feeling-groups">
          {vocabulary.map((group) => {
            const available = group.feelings.filter(
              (name) =>
                !selected.has(name) && (!needle || name.includes(needle)),
            );
            return (
              available.length > 0 && (
                <section key={group.title}>
                  <h3>{group.title}</h3>
                  <div className="ww-feeling-chips">
                    {available.map((name) => (
                      <button
                        type="button"
                        className="secondary"
                        key={name}
                        disabled={disabled}
                        onClick={() => pick(name)}
                      >
                        {name}
                      </button>
                    ))}
                  </div>
                </section>
              )
            );
          })}
        </div>
        {needle &&
          !vocabulary.some((g) =>
            g.feelings.some((n) => n.includes(needle) && !selected.has(n)),
          ) && <p role="status">לא נמצאו רגשות מתאימים</p>}
        <button
          type="button"
          className="ww-text-button"
          disabled={disabled}
          onClick={() => {
            setCustom(query.trim());
            setCustomOpen(true);
            setError("");
          }}
        >
          <Plus size={16} />
          רגש אחר
        </button>
        {customOpen && (
          <div className="ww-custom-feeling">
            <label htmlFor={`${id}-custom`}>שם הרגש</label>
            <input
              id={`${id}-custom`}
              autoFocus
              maxLength={50000}
              value={custom}
              disabled={disabled}
              onChange={(e) => {
                setCustom(e.target.value);
                setError("");
              }}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  pick(custom);
                }
              }}
            />
            <button
              type="button"
              disabled={disabled || !custom.trim()}
              onClick={() => pick(custom)}
            >
              הוספה
            </button>
            {error && (
              <p role="alert" className="ww-tone-error">
                {error}
              </p>
            )}
          </div>
        )}
      </div>
    </>
  );
}

function ThinkingErrorPicker({
  value,
  disabled,
  onChange,
}: {
  value: unknown;
  disabled: boolean;
  onChange: (value: string[] | null) => void;
}) {
  const id = useId();
  const panel = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const selected = Array.isArray(value) ? (value as string[]) : [];
  const close = () => {
    panel.current?.hidePopover();
    trigger.current?.focus();
  };
  useEffect(() => {
    if (disabled) panel.current?.hidePopover();
  }, [disabled]);
  return (
    <>
      <div className="ww-thinking-selected">
        {thinkingErrors
          .filter(([code]) => selected.includes(code))
          .map(([code, key]) => (
            <button
              type="button"
              className="secondary"
              key={code}
              disabled={disabled}
              aria-label={`הסרת ${String((mobile as Record<string, unknown>)[key])}`}
              onClick={() => {
                const next = selected.filter((v) => v !== code);
                onChange(next.length ? next : null);
              }}
            >
              <span>{String((mobile as Record<string, unknown>)[key])}</span>
              <X size={16} />
            </button>
          ))}
      </div>
      <button
        ref={trigger}
        type="button"
        className="secondary"
        popoverTarget={id}
        disabled={disabled}
      >
        {selected.length ? "שינוי הבחירה" : "בחירת טעויות חשיבה"}
      </button>
      <div
        id={id}
        ref={panel}
        popover="auto"
        className="ww-feeling-picker ww-thinking-picker"
        dir="rtl"
      >
        <div className="ww-picker-head">
          <h2>בחירת טעויות חשיבה</h2>
          <button
            type="button"
            className="ww-text-button"
            aria-label="סגירת בחירת טעויות חשיבה"
            onClick={close}
          >
            <X size={20} />
          </button>
        </div>
        <div className="ww-thinking-catalogue">
          {thinkingErrors.map(([code, key]) => (
            <label key={code}>
              <input
                type="checkbox"
                checked={selected.includes(code)}
                disabled={disabled}
                onChange={(e) => {
                  const next = e.target.checked
                    ? [...selected, code]
                    : selected.filter((v) => v !== code);
                  onChange(next.length ? next : null);
                }}
              />
              <span>{String((mobile as Record<string, unknown>)[key])}</span>
            </label>
          ))}
        </div>
        <button type="button" onClick={close}>
          סיום הבחירה
        </button>
      </div>
      <div className="ww-errors">
        <label className="ww-none">
          <input
            type="checkbox"
            checked={Array.isArray(value) && value.length === 0}
            disabled={disabled}
            onChange={(e) => onChange(e.target.checked ? [] : null)}
          />
          {ww.thinkingNone}
        </label>
      </div>
      {value === null && <p className="ww-quiet">{ww.thinkingUnaddressed}</p>}
    </>
  );
}

export function DiaryWorksheet({
  item,
  onChange,
  disabled,
}: {
  item: Worksheet;
  onChange: (next: Worksheet) => void;
  disabled: boolean;
}) {
  const d = item.data,
    third = item.type === "diary_three";
  const set = (key: string, value: unknown) =>
    onChange(updateItem(item, { data: { [key]: value } }));
  const feelings = rows(d.feelings),
    thoughts = rows(d.automatic_thoughts);
  const patch = (key: string, index: number, field: string, value: unknown) =>
    set(
      key,
      rows(d[key]).map((row, i) =>
        i === index ? { ...row, [field]: value } : row,
      ),
    );
  const textList = (
    key: string,
    title: string,
    object: boolean,
    rating?: string,
  ) => {
    const values = Array.isArray(d[key]) ? (d[key] as unknown[]) : [];
    return (
      <Section title={title}>
        <div className="ww-rows">
          {values.map((value, index) => (
            <div className="ww-diary-row" key={index}>
              <div className="ww-diary-row-head">
                <label htmlFor={`${item.id}-${key}-${index}`}>
                  {title} {index + 1}
                </label>
                <button
                  type="button"
                  className="ww-text-button ww-danger-text"
                  aria-label={`${ww.removeRow} ${title} ${index + 1}`}
                  disabled={disabled || values.length <= 1}
                  onClick={() =>
                    set(
                      key,
                      values.filter((_, i) => i !== index),
                    )
                  }
                >
                  <Trash2 size={16} />
                </button>
              </div>
              <GrowingText
                id={`${item.id}-${key}-${index}`}
                disabled={disabled}
                value={
                  object ? String((value as Row).text ?? "") : String(value)
                }
                onChange={(e) =>
                  object
                    ? patch(key, index, "text", e.target.value)
                    : set(
                        key,
                        values.map((v, i) =>
                          i === index ? e.target.value : v,
                        ),
                      )
                }
              />
              {rating && (
                <Rating
                  title={
                    rating === "beliefBefore" ? "אמונה לפני" : "אחוז אמונה"
                  }
                  value={(value as Row)[rating]}
                  disabled={disabled}
                  onChange={(v) => patch(key, index, rating, v)}
                />
              )}
            </div>
          ))}
        </div>
        <button
          type="button"
          className="secondary"
          disabled={disabled || values.length >= 100}
          onClick={() =>
            set(key, [
              ...values,
              object
                ? key === "automatic_thoughts"
                  ? { text: "", beliefBefore: null, beliefAfter: null }
                  : { text: "", belief: null }
                : "",
            ])
          }
        >
          <Plus size={16} />
          {ww.addRow}
        </button>
      </Section>
    );
  };
  return (
    <div className={`ww-diary-grid ww-diary-${item.type}`}>
      <Section title={third ? ww.situation : ww.event}>
        <label className="ww-sr" htmlFor={`${item.id}-event`}>
          {third ? ww.situation : ww.event}
        </label>
        <GrowingText
          id={`${item.id}-event`}
          disabled={disabled}
          value={String(d[third ? "situation" : "event"] ?? "")}
          onChange={(e) => set(third ? "situation" : "event", e.target.value)}
        />
      </Section>
      {textList(
        "automatic_thoughts",
        he.Diaries016,
        third,
        third ? "beliefBefore" : undefined,
      )}
      <Section title={third ? "רגשות ועוצמה לפני" : he.Diaries017}>
        <div className="ww-rows">
          {feelings.map((row, index) =>
            String(row.name ?? "").trim() ? (
              <div className="ww-diary-row" key={index}>
                <div className="ww-diary-row-head">
                  <strong>{String(row.name)}</strong>
                  <button
                    type="button"
                    className="ww-text-button ww-danger-text"
                    aria-label={`הסרת רגש ${row.name}`}
                    disabled={disabled}
                    onClick={() =>
                      set(
                        "feelings",
                        feelings.filter((_, i) => i !== index),
                      )
                    }
                  >
                    <Trash2 size={16} />
                  </button>
                </div>
                <Rating
                  label={third ? "עוצמה לפני" : ww.intensity}
                  title={`${third ? "עוצמה לפני" : ww.intensity} — ${row.name}`}
                  value={row[third ? "intensityBefore" : "intensity"]}
                  disabled={disabled}
                  onChange={(v) =>
                    patch(
                      "feelings",
                      index,
                      third ? "intensityBefore" : "intensity",
                      v,
                    )
                  }
                />
              </div>
            ) : null,
          )}
        </div>
        <FeelingPicker
          values={feelings}
          third={third}
          disabled={disabled}
          onChange={(v) => set("feelings", v)}
        />
      </Section>
      {item.type === "diary_one" ? (
        <Section title={ww.behaviour}>
          <label className="ww-sr" htmlFor={`${item.id}-behaviour`}>
            {ww.behaviour}
          </label>
          <GrowingText
            id={`${item.id}-behaviour`}
            disabled={disabled}
            value={String(d.behaviour ?? "")}
            onChange={(e) => set("behaviour", e.target.value)}
          />
          <label htmlFor={`${item.id}-symptoms`}>{ww.symptoms}</label>
          <GrowingText
            id={`${item.id}-symptoms`}
            disabled={disabled}
            value={String(d.physical_symptoms ?? "")}
            onChange={(e) => set("physical_symptoms", e.target.value)}
          />
        </Section>
      ) : (
        <>
          <Section title={he.Diaries020}>
            <ThinkingErrorPicker
              value={d.thinking_errors}
              disabled={disabled}
              onChange={(v) => set("thinking_errors", v)}
            />
          </Section>
          {textList(
            "alternative_thoughts",
            he.Diaries021,
            third,
            third ? "belief" : undefined,
          )}
        </>
      )}
      {third && (
        <>
          <Section title="הערכה מחדש של המחשבות האוטומטיות">
            {thoughts.map((row, index) => (
              <div className="ww-diary-row" key={index}>
                <p className="ww-original-text">{String(row.text ?? "")}</p>
                <p className="ww-quiet">
                  אמונה לפני:{" "}
                  <b dir="ltr">
                    {row.beliefBefore == null ? "—" : `${row.beliefBefore}%`}
                  </b>
                </p>
                <Rating
                  label="אמונה אחרי"
                  title={`אמונה אחרי — ${index + 1}`}
                  value={row.beliefAfter}
                  disabled={disabled}
                  onChange={(v) =>
                    patch("automatic_thoughts", index, "beliefAfter", v)
                  }
                />
              </div>
            ))}
          </Section>
          <Section title="רגשות ועוצמה אחרי">
            {feelings
              .filter((row) => String(row.name ?? "").trim())
              .map((row) => {
                const index = feelings.indexOf(row);
                return (
                  <div className="ww-diary-row" key={index}>
                    <strong>{String(row.name)}</strong>
                    <p className="ww-quiet">
                      עוצמה לפני:{" "}
                      <b dir="ltr">
                        {row.intensityBefore == null
                          ? "—"
                          : `${row.intensityBefore}%`}
                      </b>
                    </p>
                    <Rating
                      label="עוצמה אחרי"
                      title={`עוצמה אחרי — ${row.name}`}
                      value={row.intensityAfter}
                      disabled={disabled}
                      onChange={(v) =>
                        patch("feelings", index, "intensityAfter", v)
                      }
                    />
                  </div>
                );
              })}
          </Section>
        </>
      )}
    </div>
  );
}
