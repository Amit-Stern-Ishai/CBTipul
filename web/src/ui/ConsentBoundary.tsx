import { useEffect, useState, type ReactNode } from "react";
import {
  consents,
  type ConsentRecord,
  type ConsentType,
} from "../data/consent";
import { he } from "../he";
export function ConsentBoundary({
  account,
  type,
  title,
  description,
  accept,
  decline,
  children,
  wording,
  declineLabel = he.consentDecline,
}: {
  account: string;
  type: ConsentType;
  title: string;
  description: string;
  accept: string;
  decline: () => Promise<void>;
  children: ReactNode;
  wording?: ReactNode;
  declineLabel?: string;
}) {
  const [record, setRecord] = useState<ConsentRecord | null>(null),
    [loading, setLoading] = useState(true),
    [busy, setBusy] = useState(false),
    [error, setError] = useState<string | null>(null),
    [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let live = true;
    setRecord(null);
    setLoading(true);
    setError(null);
    const load = () => {
      setLoading(true);
      consents
        .lookup(account, type)
        .then(
          (r) => {
            if (live) {
              setRecord(r);
              setError(null);
            }
          },
          () => {
            if (live) {
              setRecord(null);
              setError(he.consentLookupFailed);
            }
          },
        )
        .finally(() => {
          if (live) setLoading(false);
        });
    };
    load();
    return () => {
      live = false;
    };
  }, [account, type, attempt]);
  const decide = async (decision: "accepted" | "declined") => {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      const result = await consents.decide(account, type, decision);
      setRecord(result);
      if (decision === "declined") await decline();
    } catch {
      setError(he.consentSaveFailed);
    } finally {
      setBusy(false);
    }
  };
  if (loading)
    return (
      <section className="cb-consent" role="status">
        {he.consentChecking}
      </section>
    );
  if (record?.status === "accepted") return children;
  if (!record)
    return (
      <section className="cb-consent" aria-label={title}>
        <h2>{title}</h2>
        <p role="alert">{error ?? he.consentLookupFailed}</p>
        <button onClick={() => setAttempt((v) => v + 1)}>
          {he.consentRetry}
        </button>
      </section>
    );
  return (
    <section className="cb-consent" aria-label={title}>
      <h2>{title}</h2>
      <p>{description}</p>
      {wording}
      {record.status === "declined" && <p>{he.consentDeclined}</p>}
      {error && <p role="alert">{error}</p>}
      <div className="ww-actions">
        <button
          disabled={busy}
          aria-busy={busy}
          onClick={() => void decide("accepted")}
        >
          {busy ? he.consentSaving : accept}
        </button>
        <button
          className="secondary"
          disabled={busy}
          onClick={() => void decide("declined")}
        >
          {declineLabel}
        </button>
      </div>
    </section>
  );
}
