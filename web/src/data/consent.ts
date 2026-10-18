import { supabase } from "./client";
// Proposed wording identifiers. Production stays disabled until registry and live consent review.
export const consentVersions = {
  terms_privacy: "2026-08-29",
  clinical_text_processing: "2026-10-14",
  ai_data_sharing: "2026-08-29",
} as const;
export type ConsentType = keyof typeof consentVersions;
export type ConsentDecision = "accepted" | "declined" | "revoked";
export type ConsentRecord = {
  therapist_id: string;
  consent_type: ConsentType;
  required_version: string;
  accepted_version: string | null;
  accepted_at: string | null;
  revoked_at: string | null;
  status: "required" | ConsentDecision;
  revision: number;
};
export class ConsentError extends Error {
  constructor(
    public code:
      | "consent"
      | "consent_lookup"
      | "consent_persist"
      | "consent_unavailable"
      | "consent_changed"
      | "consent_programming"
      | "stale",
  ) {
    super(code);
  }
}
type Args = Readonly<{
  p_consent_type: ConsentType;
  p_required_version: string;
  p_decision: ConsentDecision;
  p_request_id: string;
  p_expected_revision: number;
}>;
type Rpc = (
  name: string,
  params: Readonly<Record<string, string | number>>,
) => Promise<{ data: unknown; error: unknown }>;
export type ConsentState = Readonly<{
  record: ConsentRecord | null;
  pending: Args | null;
  busy: boolean;
  error: ConsentError["code"] | null;
}>;
const empty: ConsentState = Object.freeze({
  record: null,
  pending: null,
  busy: false,
  error: null,
});
function errorName(error: unknown) {
  if (!error || typeof error !== "object") return "";
  const e = error as { code?: string; message?: string };
  return e.message?.startsWith("consent_") ||
    e.message === "unsupported_consent_type" ||
    e.message === "invalid_consent_request"
    ? e.message
    : (e.code ?? "");
}
export class ConsentStore {
  private account: string | null = null;
  private generation = 0;
  private receipts = new Map<ConsentType, ConsentRecord>();
  private epochs = new Map<ConsentType, number>();
  private states = new Map<ConsentType, ConsentState>();
  private lookups = new Map<ConsentType, Promise<ConsentRecord>>();
  private operations = new Map<ConsentType, Promise<ConsentRecord>>();
  private listeners = new Set<() => void>();
  constructor(
    private rpc: Rpc,
    private enabled: boolean,
    private uuid: () => string = () => crypto.randomUUID(),
  ) {}
  subscribe = (listener: () => void) => {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  };
  snapshot = (account: string, type: ConsentType): ConsentState =>
    this.account === account ? (this.states.get(type) ?? empty) : empty;
  private update(type: ConsentType, patch: Partial<ConsentState>) {
    this.states.set(
      type,
      Object.freeze({ ...(this.states.get(type) ?? empty), ...patch }),
    );
    this.listeners.forEach((listener) => listener());
  }
  setAccount(account: string | null) {
    if (this.account === account) return;
    this.account = account;
    this.generation++;
    this.states.clear();
    this.receipts.clear();
    this.epochs.clear();
    this.lookups.clear();
    this.operations.clear();
    this.listeners.forEach((listener) => listener());
  }
  private context(account: string) {
    if (this.account !== account) throw new ConsentError("stale");
    if (!this.enabled) throw new ConsentError("consent_unavailable");
    const generation = this.generation;
    return () => {
      if (generation !== this.generation || account !== this.account)
        throw new ConsentError("stale");
    };
  }
  private record(
    value: unknown,
    account: string,
    type: ConsentType,
  ): ConsentRecord {
    const r = value as ConsentRecord | null;
    const timestamp = (v: unknown) =>
      typeof v === "string" && Number.isFinite(Date.parse(v));
    if (
      !r ||
      Array.isArray(r) ||
      r.therapist_id !== account ||
      r.consent_type !== type ||
      r.required_version !== consentVersions[type] ||
      !["required", "accepted", "declined", "revoked"].includes(r.status) ||
      !Number.isSafeInteger(r.revision) ||
      r.revision < 0 ||
      !(
        r.accepted_version === null || typeof r.accepted_version === "string"
      ) ||
      !(r.accepted_at === null || timestamp(r.accepted_at)) ||
      !(r.revoked_at === null || timestamp(r.revoked_at)) ||
      (r.status === "accepted" &&
        (r.accepted_version !== consentVersions[type] ||
          !timestamp(r.accepted_at) ||
          r.revoked_at !== null)) ||
      (r.status === "revoked" && !timestamp(r.revoked_at))
    )
      throw new Error("invalid consent receipt");
    const previous = this.receipts.get(type);
    if (
      previous &&
      (r.revision < previous.revision ||
        (r.revision === previous.revision && r.status !== previous.status))
    )
      throw new Error("stale consent receipt");
    const receipt = Object.freeze({ ...r });
    return receipt;
  }
  // Navigation reuses account-scoped state. Processing and deliberate decisions use fresh lookup.
  async ensure(account: string, type: ConsentType) {
    this.context(account);
    const state = this.snapshot(account, type);
    if (state.pending || state.error)
      throw new ConsentError(state.error ?? "consent_persist");
    return state.record ?? this.lookup(account, type);
  }
  async lookup(account: string, type: ConsentType): Promise<ConsentRecord> {
    const check = this.context(account),
      epoch = this.epochs.get(type) ?? 0;
    const existing = this.lookups.get(type);
    if (existing) return existing;
    const request = (async () => {
      try {
        const { data, error } = await this.rpc("get_my_consent", {
          p_consent_type: type,
          p_required_version: consentVersions[type],
        });
        check();
        if (epoch !== (this.epochs.get(type) ?? 0))
          throw new ConsentError("stale");
        if (error) throw error;
        const record = this.record(data, account, type);
        this.receipts.set(type, record);
        this.update(type, { record, error: null });
        return record;
      } catch (error) {
        check();
        if (
          epoch !== (this.epochs.get(type) ?? 0) ||
          (error instanceof ConsentError && error.code === "stale")
        )
          throw new ConsentError("stale");
        this.update(type, { record: null, error: "consent_lookup" });
        throw new ConsentError("consent_lookup");
      }
    })();
    this.lookups.set(type, request);
    try {
      return await request;
    } finally {
      if (this.lookups.get(type) === request) this.lookups.delete(type);
    }
  }
  private operate(
    account: string,
    type: ConsentType,
    action: () => Promise<ConsentRecord>,
  ): Promise<ConsentRecord> {
    const check = this.context(account);
    const existing = this.operations.get(type);
    if (existing) return existing;
    this.update(type, { busy: true, error: null });
    const request = action().finally(() => {
      try {
        check();
      } catch {
        return;
      }
      if (this.operations.get(type) === request) {
        this.operations.delete(type);
        this.update(type, { busy: false });
      }
    });
    this.operations.set(type, request);
    return request;
  }
  decide(
    account: string,
    type: ConsentType,
    decision: ConsentDecision,
  ): Promise<ConsentRecord> {
    this.context(account);
    if (this.snapshot(account, type).pending)
      return Promise.reject(new ConsentError("consent_persist"));
    return this.operate(account, type, async () => {
      this.lookups.delete(type);
      this.epochs.set(type, (this.epochs.get(type) ?? 0) + 1);
      const current = await this.lookup(account, type);
      const args: Args = Object.freeze({
        p_consent_type: type,
        p_required_version: consentVersions[type],
        p_decision: decision,
        p_request_id: this.uuid(),
        p_expected_revision: current.revision,
      });
      this.update(type, { pending: args });
      return this.submit(account, type, args);
    });
  }
  retry(account: string, type: ConsentType): Promise<ConsentRecord> {
    this.context(account);
    const args = this.snapshot(account, type).pending;
    if (!args) return Promise.reject(new ConsentError("consent_persist"));
    return this.operate(account, type, () => this.submit(account, type, args));
  }
  private async submit(
    account: string,
    type: ConsentType,
    args: Args,
  ): Promise<ConsentRecord> {
    const check = this.context(account);
    this.lookups.delete(type);
    const epoch = (this.epochs.get(type) ?? 0) + 1;
    this.epochs.set(type, epoch);
    try {
      const { data, error } = await this.rpc("record_my_consent", args);
      check();
      if (epoch !== this.epochs.get(type)) throw new ConsentError("stale");
      if (error) throw error;
      const record = this.record(data, account, type);
      if (
        record.status !== args.p_decision ||
        record.revision < args.p_expected_revision
      )
        throw new Error("decision not acknowledged");
      this.lookups.delete(type);
      this.epochs.set(type, epoch + 1);
      this.receipts.set(type, record);
      this.update(type, { record, pending: null, error: null });
      return record;
    } catch (error) {
      check();
      if (epoch !== this.epochs.get(type)) throw new ConsentError("stale");
      this.lookups.delete(type);
      this.epochs.set(type, epoch + 1);
      const name = errorName(error);
      if (
        ["consent_revision_conflict", "consent_request_superseded"].includes(
          name,
        )
      ) {
        this.update(type, {
          record: null,
          pending: null,
          error: "consent_changed",
        });
        await this.lookup(account, type);
        this.update(type, { error: "consent_changed" });
        throw new ConsentError("consent_changed");
      }
      if (name === "consent_request_id_reused") {
        this.update(type, {
          record: null,
          pending: null,
          error: "consent_programming",
        });
        throw new ConsentError("consent_programming");
      }
      // SQL/PostgREST errors are known refusals. Transport failures and malformed success
      // responses have uncertain outcomes: retain the identical request in memory only.
      this.update(type, {
        record: null,
        pending: /^(?:[0-9A-Z]{5}|PGRST\d+)$/.test(name) || name.startsWith("consent_") || ["unsupported_consent_type", "invalid_consent_request"].includes(name) ? null : args,
        error: "consent_persist",
      });
      throw new ConsentError("consent_persist");
    }
  }
  refuse(account: string, type: ConsentType) {
    if (account !== this.account) return;
    this.lookups.delete(type);
    this.epochs.set(type, (this.epochs.get(type) ?? 0) + 1);
    this.update(type, { record: null, error: "consent_lookup" });
  }
  async require(account: string, type: ConsentType) {
    if (this.snapshot(account, type).pending)
      throw new ConsentError("consent_persist");
    if ((await this.lookup(account, type)).status !== "accepted")
      throw new ConsentError("consent");
  }
}
export const consents = new ConsentStore(
  async (name, params) => await supabase.rpc(name, params),
  import.meta.env.VITE_SERVER_CONSENT_ENABLED === "true",
);
