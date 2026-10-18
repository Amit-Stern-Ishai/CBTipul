import { supabase } from "./client";
// Proposed contract: backend implementation/version approval is a release dependency.
// Never infer consent from login, JWT metadata, old local flags or a failed lookup.
export const consentVersions = {
  terms_privacy: "2026-08-29",
  clinical_text_processing: "2026-10-14",
  ai_data_sharing: "2026-08-29",
} as const;
export type ConsentType = keyof typeof consentVersions;
export type ConsentStatus = "accepted" | "required" | "declined" | "revoked";
export type ConsentRecord = {
  therapist_id: string;
  consent_type: ConsentType;
  required_version: string;
  accepted_version: string | null;
  accepted_at: string | null;
  revoked_at: string | null;
  status: ConsentStatus;
};
export class ConsentError extends Error {
  constructor(
    public code:
      | "consent"
      | "consent_lookup"
      | "consent_persist"
      | "consent_unavailable"
      | "stale",
  ) {
    super(code);
  }
}
type Rpc = (
  name: string,
  params: Record<string, string>,
) => Promise<{ data: unknown; error: unknown }>;
export class ConsentStore {
  private account: string | null = null;
  private generation = 0;
  private decisions = new Map<ConsentType, number>();
  private lookups = new Map<string, Promise<ConsentRecord>>();
  constructor(
    private rpc: Rpc,
    private enabled: boolean,
  ) {}
  setAccount(account: string | null) {
    if (account !== this.account) {
      this.account = account;
      this.generation++;
      this.lookups.clear();
      this.decisions.clear();
    }
  }
  private context(account: string) {
    if (this.account !== account) throw new ConsentError("stale");
    if (!this.enabled) throw new ConsentError("consent_unavailable");
    const generation = this.generation;
    return () => {
      if (generation !== this.generation || this.account !== account)
        throw new ConsentError("stale");
    };
  }
  private record(
    value: unknown,
    account: string,
    type: ConsentType,
  ): ConsentRecord {
    const r = value as ConsentRecord | null;
    if (
      !r ||
      r.therapist_id !== account ||
      r.consent_type !== type ||
      r.required_version !== consentVersions[type] ||
      !["accepted", "required", "declined", "revoked"].includes(r.status)
    )
      throw new Error("invalid consent receipt");
    if (
      r.status === "accepted" &&
      (r.accepted_version !== consentVersions[type] ||
        typeof r.accepted_at !== "string" ||
        !Number.isFinite(Date.parse(r.accepted_at)) ||
        r.revoked_at !== null)
    )
      throw new Error("invalid acceptance");
    return r;
  }
  async lookup(account: string, type: ConsentType): Promise<ConsentRecord> {
    const check = this.context(account),
      key = `${account}:${type}`;
    const decision = this.decisions.get(type) ?? 0;
    const pending = this.lookups.get(key);
    if (pending) return pending;
    const request = (async () => {
      try {
        const { data, error } = await this.rpc("get_my_consent", {
          p_consent_type: type,
          p_required_version: consentVersions[type],
        });
        check();
        if (decision !== (this.decisions.get(type) ?? 0))
          throw new ConsentError("stale");
        if (error) throw error;
        return this.record(data, account, type);
      } catch (error) {
        check();
        if (error instanceof ConsentError) throw error;
        throw new ConsentError("consent_lookup");
      }
    })();
    this.lookups.set(key, request);
    try {
      return await request;
    } finally {
      if (this.lookups.get(key) === request) this.lookups.delete(key);
    }
  }
  async decide(
    account: string,
    type: ConsentType,
    decision: "accepted" | "declined" | "revoked",
  ): Promise<ConsentRecord> {
    const check = this.context(account);
    // A completed decision invalidates outstanding pre-decision lookups.
    this.lookups.delete(`${account}:${type}`);
    this.decisions.set(type, (this.decisions.get(type) ?? 0) + 1);
    try {
      const { data, error } = await this.rpc("record_my_consent", {
        p_consent_type: type,
        p_required_version: consentVersions[type],
        p_decision: decision,
      });
      check();
      if (error) throw error;
      const record = this.record(data, account, type);
      if (record.status !== decision)
        throw new Error("decision not acknowledged");
      return record;
    } catch (error) {
      check();
      if (error instanceof ConsentError) throw error;
      throw new ConsentError("consent_persist");
    }
  }
  async require(account: string, type: ConsentType) {
    if ((await this.lookup(account, type)).status !== "accepted")
      throw new ConsentError("consent");
  }
}
export const consents = new ConsentStore(
  async (name, params) => await supabase.rpc(name, params),
  import.meta.env.VITE_SERVER_CONSENT_ENABLED === "true",
);
