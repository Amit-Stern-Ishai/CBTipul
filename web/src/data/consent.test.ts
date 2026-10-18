import { describe, it, expect, vi } from "vitest";
import {
  ConsentStore,
  consentVersions,
  type ConsentType,
  type ConsentRecord,
} from "./consent";
type Params = Readonly<Record<string, string | number>>;
const receipt = (
  type: ConsentType = "terms_privacy",
  status: ConsentRecord["status"] = "required",
  revision = 0,
  account = "a",
): ConsentRecord => ({
  therapist_id: account,
  consent_type: type,
  required_version: consentVersions[type],
  status,
  revision,
  accepted_version: status === "accepted" ? consentVersions[type] : null,
  accepted_at: status === "accepted" ? "2026-10-18T10:00:00Z" : null,
  revoked_at: status === "revoked" ? "2026-10-18T11:00:00Z" : null,
});
function backend() {
  const records = new Map<string, ConsentRecord>(),
    requests = new Map<string, { args: Params; result: ConsentRecord }>();
  let account = "a",
    loseResponse = false,
    refusal = "";
  const rpc = vi.fn(
    async (
      name: string,
      p: Params,
    ): Promise<{ data: unknown; error: unknown }> => {
      if (refusal)
        return { data: null, error: { code: "P0001", message: refusal } };
      const type = p.p_consent_type as ConsentType,
        key = `${account}:${type}`;
      const current = records.get(key) ?? receipt(type, "required", 0, account);
      if (p.p_required_version !== consentVersions[type])
        return { data: null, error: { message: "consent_version_mismatch" } };
      if (name === "get_my_consent") return { data: current, error: null };
      expect(name).toBe("record_my_consent");
      expect(Object.keys(p).sort()).toEqual(
        [
          "p_consent_type",
          "p_required_version",
          "p_decision",
          "p_request_id",
          "p_expected_revision",
        ].sort(),
      );
      const id = `${account}:${p.p_request_id}`,
        prior = requests.get(id);
      if (prior) {
        if (JSON.stringify(prior.args) !== JSON.stringify(p))
          return {
            data: null,
            error: { message: "consent_request_id_reused" },
          };
        if (prior.result.revision !== current.revision)
          return {
            data: null,
            error: { message: "consent_request_superseded" },
          };
        return { data: prior.result, error: null };
      }
      if (p.p_expected_revision !== current.revision)
        return { data: null, error: { message: "consent_revision_conflict" } };
      const result =
        current.status === p.p_decision
          ? current
          : receipt(
              type,
              p.p_decision as ConsentRecord["status"],
              current.revision + 1,
              account,
            );
      records.set(key, result);
      requests.set(id, { args: { ...p }, result });
      if (loseResponse) {
        loseResponse = false;
        throw new TypeError("network");
      }
      return { data: result, error: null };
    },
  );
  return {
    rpc,
    records,
    requests,
    setAccount: (v: string) => {
      account = v;
    },
    lose: () => {
      loseResponse = true;
    },
    refuse: (v: string) => {
      refusal = v;
    },
  };
}
function store(b = backend(), uuid?: () => string) {
  const s = new ConsentStore(b.rpc, true, uuid);
  s.setAccount("a");
  return { s, b };
}
function deferred<T>() {
  let resolve!: (v: T) => void;
  const promise = new Promise<T>((r) => {
    resolve = r;
  });
  return { promise, resolve };
}
describe("persistent consent revision contract (modeled RPC, not live Supabase)", () => {
  it("is disabled by default configuration and never consults browser flags", async () => {
    const rpc = vi.fn();
    const s = new ConsentStore(rpc, false);
    s.setAccount("a");
    await expect(s.ensure("a", "terms_privacy")).rejects.toMatchObject({
      code: "consent_unavailable",
    });
    expect(rpc).not.toHaveBeenCalled();
  });
  it("persists across reload/login, shares navigation state, and separates types/accounts", async () => {
    const { s, b } = store();
    await s.decide("a", "terms_privacy", "accepted");
    const count = b.rpc.mock.calls.length;
    expect((await s.ensure("a", "terms_privacy")).status).toBe("accepted");
    expect(b.rpc).toHaveBeenCalledTimes(count);
    expect((await s.ensure("a", "clinical_text_processing")).status).toBe(
      "required",
    );
    expect((await s.ensure("a", "ai_data_sharing")).status).toBe("required");
    const reload = store(b).s;
    expect((await reload.ensure("a", "terms_privacy")).status).toBe("accepted");
    s.setAccount(null);
    b.setAccount("b");
    s.setAccount("b");
    expect((await s.ensure("b", "terms_privacy")).status).toBe("required");
    b.setAccount("a");
    s.setAccount("a");
    expect((await s.ensure("a", "terms_privacy")).status).toBe("accepted");
  });
  it("requires deliberate acceptance when the server reports an older wording acceptance", async () => {
    const b = backend();
    b.records.set("a:terms_privacy", {
      ...receipt("terms_privacy", "required", 7),
      accepted_version: "previous-wording-version",
      accepted_at: "2026-08-01T10:00:00Z",
    });
    const { s } = store(b);
    expect((await s.ensure("a", "terms_privacy")).status).toBe("required");
    await expect(s.require("a", "terms_privacy")).rejects.toMatchObject({ code: "consent" });
    expect(b.rpc.mock.calls.some(([name]) => name === "record_my_consent")).toBe(false);
    const accepted = await s.decide("a", "terms_privacy", "accepted");
    expect(accepted.accepted_version).toBe(consentVersions.terms_privacy);
    expect(accepted.revision).toBe(8);
    expect((await store(b).s.ensure("a", "terms_privacy")).status).toBe("accepted");
  });
  it("uses a fresh revision and UUID for deliberate decline, revoke and reaccept", async () => {
    const { s, b } = store();
    for (const decision of [
      "declined",
      "accepted",
      "revoked",
      "accepted",
    ] as const)
      expect((await s.decide("a", "terms_privacy", decision)).status).toBe(
        decision,
      );
    const writes = b.rpc.mock.calls
      .filter(([n]) => n === "record_my_consent")
      .map(([, p]) => p);
    expect(writes.map((p) => p.p_expected_revision)).toEqual([0, 1, 2, 3]);
    expect(new Set(writes.map((p) => p.p_request_id)).size).toBe(4);
    expect(b.rpc.mock.calls.map(([n]) => n)).toEqual(
      Array.from({ length: 4 }, () => [
        "get_my_consent",
        "record_my_consent",
      ]).flat(),
    );
  });
  it("freezes all five arguments and retries an uncertain response exactly once without another lookup", async () => {
    const { s, b } = store();
    b.lose();
    await expect(
      s.decide("a", "terms_privacy", "accepted"),
    ).rejects.toMatchObject({ code: "consent_persist" });
    const pending = s.snapshot("a", "terms_privacy").pending!;
    expect(Object.isFrozen(pending)).toBe(true);
    await expect(s.require("a", "terms_privacy")).rejects.toThrow();
    const [a, c] = await Promise.all([
      s.retry("a", "terms_privacy"),
      s.retry("a", "terms_privacy"),
    ]);
    expect(a).toEqual(c);
    expect(a.revision).toBe(1);
    const writes = b.rpc.mock.calls.filter(([n]) => n === "record_my_consent");
    expect(writes).toHaveLength(2);
    expect(writes[0][1]).toBe(writes[1][1]);
    expect(
      b.rpc.mock.calls.filter(([n]) => n === "get_my_consent"),
    ).toHaveLength(1);
    expect(b.requests.size).toBe(1);
    expect(s.snapshot("a", "terms_privacy").pending).toBeNull();
  });
  it("coalesces duplicate deliberate clicks", async () => {
    const { s, b } = store();
    await Promise.all([
      s.decide("a", "terms_privacy", "accepted"),
      s.decide("a", "terms_privacy", "accepted"),
    ]);
    expect(b.requests.size).toBe(1);
  });
  it("does not restore acceptance when a delayed retry follows revocation", async () => {
    const { s, b } = store();
    b.lose();
    await expect(s.decide("a", "terms_privacy", "accepted")).rejects.toThrow();
    const other = store(b).s;
    await other.decide("a", "terms_privacy", "revoked");
    await expect(s.retry("a", "terms_privacy")).rejects.toMatchObject({
      code: "consent_changed",
    });
    expect(s.snapshot("a", "terms_privacy")).toMatchObject({
      pending: null,
      record: { status: "revoked", revision: 2 },
      busy: false,
    });
    expect(b.requests.size).toBe(2);
    await s.decide("a", "terms_privacy", "accepted");
    expect(b.requests.size).toBe(3);
  });
  it("refreshes revision conflicts but never automatically resubmits", async () => {
    const b = backend();
    let first = true;
    const rpc = vi.fn(async (n: string, p: Params) => {
      if (n === "record_my_consent" && first) {
        first = false;
        b.records.set(
          "a:terms_privacy",
          receipt("terms_privacy", "declined", 1),
        );
      }
      return b.rpc(n, p);
    });
    const s = new ConsentStore(rpc, true);
    s.setAccount("a");
    await expect(
      s.decide("a", "terms_privacy", "accepted"),
    ).rejects.toMatchObject({ code: "consent_changed" });
    expect(s.snapshot("a", "terms_privacy").record?.status).toBe("declined");
    expect(
      rpc.mock.calls.filter(([n]) => n === "record_my_consent"),
    ).toHaveLength(1);
    await s.decide("a", "terms_privacy", "accepted");
    const writes = rpc.mock.calls.filter(([n]) => n === "record_my_consent");
    expect(writes[1][1].p_request_id).not.toBe(writes[0][1].p_request_id);
    expect(writes[1][1].p_expected_revision).toBe(1);
  });
  it("treats changed arguments under a reused UUID as a programming error", async () => {
    const { s, b } = store(
      backend(),
      () => "11111111-1111-4111-8111-111111111111",
    );
    await s.decide("a", "terms_privacy", "accepted");
    await expect(
      s.decide("a", "terms_privacy", "revoked"),
    ).rejects.toMatchObject({ code: "consent_programming" });
    expect(s.snapshot("a", "terms_privacy")).toMatchObject({
      record: null,
      pending: null,
      error: "consent_programming",
    });
    expect(b.requests.size).toBe(1);
  });
  it.each([
    "unsupported_consent_type",
    "consent_version_mismatch",
    "consent_registry_not_ready",
    "network",
  ])("keeps %s a lookup error, not required", async (failure) => {
    const { s, b } = store();
    await s.decide("a", "terms_privacy", "accepted");
    if (failure === "network")
      b.rpc.mockRejectedValueOnce(new TypeError("offline"));
    else b.refuse(failure);
    await expect(s.require("a", "terms_privacy")).rejects.toMatchObject({
      code: "consent_lookup",
    });
    expect(s.snapshot("a", "terms_privacy").record).toBeNull();
    await expect(s.ensure("a", "terms_privacy")).rejects.toThrow();
  });
  it.each([
    null,
    [],
    {},
    { revision: -1 },
    { revision: 1.5 },
    { revision: Number.MAX_SAFE_INTEGER + 1 },
    { revision: "1" },
    { revision: undefined },
    { therapist_id: "b" },
    { consent_type: "ai_data_sharing" },
    { required_version: "new" },
    { accepted_version: "old" },
    { accepted_at: "bad" },
    { accepted_at: null },
    { revoked_at: "2026-10-18T11:00:00Z" },
  ])("rejects malformed/mismatched receipt %j", async (patch) => {
    const value =
      patch === null || Array.isArray(patch) || Object.keys(patch).length === 0
        ? patch
        : { ...receipt("terms_privacy", "accepted", 1), ...patch };
    const s = new ConsentStore(
      async () => ({ data: value, error: null }),
      true,
    );
    s.setAccount("a");
    await expect(s.lookup("a", "terms_privacy")).rejects.toThrow();
    expect(s.snapshot("a", "terms_privacy").record).toBeNull();
  });
  it("retains uncertain malformed write responses for exact retries", async () => {
    const { s, b } = store();
    const real = b.rpc.getMockImplementation()!;
    b.rpc.mockImplementation(async (n, p) => {
      const r = await real(n, p);
      return n === "record_my_consent" ? { data: {}, error: null } : r;
    });
    await expect(s.decide("a", "terms_privacy", "accepted")).rejects.toThrow();
    expect(s.snapshot("a", "terms_privacy").pending).not.toBeNull();
    b.rpc.mockImplementation(real);
    expect((await s.retry("a", "terms_privacy")).status).toBe("accepted");
  });
  it.each(["lookup", "write"])(
    "ignores late %s responses after logout/account switch",
    async (phase) => {
      const b = backend(),
        wait = deferred<{ data: unknown; error: unknown }>();
      const rpc = vi.fn(async (n: string, p: Params) =>
        phase === "lookup" || n === "record_my_consent"
          ? wait.promise
          : b.rpc(n, p),
      );
      const s = new ConsentStore(rpc, true);
      s.setAccount("a");
      const pending =
        phase === "lookup"
          ? s.lookup("a", "terms_privacy")
          : s.decide("a", "terms_privacy", "accepted");
      await vi.waitFor(() =>
        expect(rpc).toHaveBeenCalledTimes(phase === "lookup" ? 1 : 2),
      );
      s.setAccount(null);
      s.setAccount("b");
      wait.resolve({
        data: receipt("terms_privacy", "accepted", 1),
        error: null,
      });
      await expect(pending).rejects.toMatchObject({ code: "stale" });
      expect(s.snapshot("b", "terms_privacy").record).toBeNull();
    },
  );
  it("invalidates a pre-decision lookup that returns late", async () => {
    const { s, b } = store();
    const wait = deferred<{ data: unknown; error: unknown }>();
    await s.decide("a", "terms_privacy", "accepted");
    b.rpc.mockImplementationOnce(() => wait.promise);
    const old = s.lookup("a", "terms_privacy");
    // A deliberate action waits for the shared authoritative lookup, then writes.
    wait.resolve({
      data: receipt("terms_privacy", "accepted", 1),
      error: null,
    });
    await old;
    await s.decide("a", "terms_privacy", "revoked");
    b.rpc.mockResolvedValueOnce({
      data: receipt("terms_privacy", "accepted", 1),
      error: null,
    });
    await expect(s.lookup("a", "terms_privacy")).rejects.toThrow();
    expect(s.snapshot("a", "terms_privacy").record).toBeNull();
  });
  it("does not let a pre-revocation read overwrite the newer receipt", async () => {
    const { s, b } = store();
    await s.decide("a", "terms_privacy", "accepted");
    const wait = deferred<{ data: unknown; error: unknown }>();
    b.rpc.mockImplementationOnce(() => wait.promise);
    const old = s.lookup("a", "terms_privacy");
    await s.decide("a", "terms_privacy", "revoked");
    wait.resolve({
      data: receipt("terms_privacy", "accepted", 1),
      error: null,
    });
    await expect(old).rejects.toMatchObject({ code: "stale" });
    expect(s.snapshot("a", "terms_privacy").record?.status).toBe("revoked");
  });
  it("clears cached evidence on a processing refusal and rejects a delayed write", async () => {
    const { s, b } = store();
    const real = b.rpc.getMockImplementation()!;
    const wait = deferred<{ data: unknown; error: unknown }>();
    b.rpc.mockImplementation(async (n, p) =>
      n === "record_my_consent" ? wait.promise : real(n, p),
    );
    const decision = s.decide("a", "terms_privacy", "accepted");
    await vi.waitFor(() =>
      expect(s.snapshot("a", "terms_privacy").pending).not.toBeNull(),
    );
    s.refuse("a", "terms_privacy");
    wait.resolve({
      data: receipt("terms_privacy", "accepted", 1),
      error: null,
    });
    await expect(decision).rejects.toMatchObject({ code: "stale" });
    expect(s.snapshot("a", "terms_privacy").record).toBeNull();
    await expect(s.ensure("a", "terms_privacy")).rejects.toThrow();
  });
  it("keeps a superseded request cleared when the follow-up lookup fails", async () => {
    const { s, b } = store();
    b.lose();
    await expect(s.decide("a", "terms_privacy", "accepted")).rejects.toThrow();
    b.rpc
      .mockResolvedValueOnce({
        data: null,
        error: { message: "consent_request_superseded" },
      })
      .mockRejectedValueOnce(new TypeError("offline"));
    await expect(s.retry("a", "terms_privacy")).rejects.toMatchObject({
      code: "consent_lookup",
    });
    expect(s.snapshot("a", "terms_privacy")).toMatchObject({
      record: null,
      pending: null,
      busy: false,
    });
  });
  it("allows a same-decision no-op with a new UUID and current revision", async () => {
    const { s, b } = store();
    const a = await s.decide("a", "terms_privacy", "accepted");
    const c = await s.decide("a", "terms_privacy", "accepted");
    expect(c).toEqual(a);
    expect(b.requests.size).toBe(2);
  });
  it("retains the frozen request for coded transport failures", async () => {
    const {s,b}=store(); const real=b.rpc.getMockImplementation()!;
    b.rpc.mockImplementation(async(n,p)=> {
      if(n==="record_my_consent") throw Object.assign(new Error("offline"),{code:"ECONNRESET"});
      return real(n,p);
    });
    await expect(s.decide("a","terms_privacy","accepted")).rejects.toThrow();
    expect(s.snapshot("a","terms_privacy").pending).not.toBeNull();
    b.rpc.mockImplementation(real); await s.retry("a","terms_privacy");
    const writes=b.rpc.mock.calls.filter(([n])=>n==="record_my_consent");expect(writes[0][1]).toBe(writes[1][1]);
  });

});
