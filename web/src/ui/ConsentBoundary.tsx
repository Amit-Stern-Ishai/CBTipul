import {
  useEffect,
  useRef,
  useState,
  useSyncExternalStore,
  type ReactNode,
} from "react";
import { consents, type ConsentType } from "../data/consent";
import { he } from "../he";
export function useConsentState(account: string, type: ConsentType) {
  return useSyncExternalStore(consents.subscribe, () =>
    consents.snapshot(account, type),
  );
}
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
  const state = useConsentState(account, type);
  const [loading, setLoading] = useState(true),
    [failed, setFailed] = useState(false);
  const generation = useRef(0);
  useEffect(() => {
    const current = ++generation.current;
    setLoading(true);
    setFailed(false);
    consents
      .ensure(account, type)
      .catch(() => {
        if (generation.current === current) setFailed(true);
      })
      .finally(() => {
        if (generation.current === current) setLoading(false);
      });
    return () => {
      generation.current++;
    };
  }, [account, type]);
  const act = async (decision?: "accepted" | "declined") => {
    if (state.busy || loading) return;
    const current = generation.current;
    const submitted = decision ?? state.pending?.p_decision;
    setFailed(false);
    setLoading(true);
    try {
      if (decision) await consents.decide(account, type, decision);
      else if (state.pending) await consents.retry(account, type);
      else await consents.lookup(account, type);
      if (generation.current === current && submitted === "declined")
        await decline();
    } catch {
      if (generation.current === current) setFailed(true);
    } finally {
      if (generation.current === current) setLoading(false);
    }
  };
  // A pending uncertain decision never unlocks the boundary, even if another read
  // has populated an accepted receipt. Processing also performs a fresh lookup.
  const allowed = state.record?.status === "accepted" && !state.pending && !state.busy && !loading;
  const [admitted, setAdmitted] = useState(false);
  useEffect(() => { if (allowed) setAdmitted(true); }, [allowed]);
  const error =
    state.error === "consent_programming"
      ? he.consentProgrammingError
      : state.error === "consent_changed"
        ? he.consentChanged
        : state.pending || state.error === "consent_persist"
          ? he.consentSaveFailed
          : he.consentLookupFailed;
  return (
    <>
    <div hidden={!allowed}>{(admitted || allowed) && children}</div>
    {!allowed && <section className="cb-consent" aria-label={title}>
      <h2>{title}</h2>
      {loading && (
        <p role="status">
          {state.busy ? he.consentSaving : he.consentChecking}
        </p>
      )}
      {(failed || state.error) && <p role="alert">{error}</p>}
      {state.pending || !state.record ? (
        <button disabled={loading || state.busy} onClick={() => void act()}>
          {he.consentRetry}
        </button>
      ) : (
        <>
          <p>{description}</p>
          {wording}
          {state.record.status === "declined" && <p>{he.consentDeclined}</p>}
          <div className="ww-actions">
            <button
              disabled={loading || state.busy}
              aria-busy={state.busy}
              onClick={() => void act("accepted")}
            >
              {state.busy ? he.consentSaving : accept}
            </button>
            <button
              className="secondary"
              disabled={loading || state.busy}
              onClick={() => void act("declined")}
            >
              {declineLabel}
            </button>
          </div>
        </>
      )}
    </section>}
    </>
  );
}
