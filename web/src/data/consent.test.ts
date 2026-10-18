import { describe, it, expect, vi } from "vitest";
import { ConsentStore, consentVersions, type ConsentType } from "./consent";
const record = (
  type: ConsentType = "terms_privacy",
  status = "accepted",
  account = "a",
) => ({
  therapist_id: account,
  consent_type: type,
  required_version: consentVersions[type],
  accepted_version: (status === "accepted" ? consentVersions[type] : null) as
    string | null,
  accepted_at: status === "accepted" ? "2026-10-15T10:00:00Z" : null,
  revoked_at: status === "revoked" ? "2026-10-15T11:00:00Z" : null,
  status,
});
describe("server consent boundary", () => {
  it("does not use local flags or call a missing backend contract", async () => {
    const rpc = vi.fn();
    const s = new ConsentStore(rpc, false);
    s.setAccount("a");
    await expect(s.require("a", "terms_privacy")).rejects.toMatchObject({
      code: "consent_unavailable",
    });
    expect(rpc).not.toHaveBeenCalled();
  });
  it("separates types and required versions and checks the server on every use", async () => {
    const rpc = vi.fn(async (_n: string, p: Record<string, string>) => ({
      data: record(p.p_consent_type as ConsentType),
      error: null,
    }));
    const s = new ConsentStore(rpc, true);
    s.setAccount("a");
    await s.require("a", "terms_privacy");
    await s.require("a", "clinical_text_processing");
    await s.require("a", "terms_privacy");
    expect(rpc).toHaveBeenCalledTimes(3);
    expect(rpc.mock.calls[1][1]).toEqual({
      p_consent_type: "clinical_text_processing",
      p_required_version: consentVersions.clinical_text_processing,
    });
  });
  it.each(["wrong_account", "old_version", "revoked", "missing_timestamp"])(
    "rejects invalid or inactive acceptance: %s",
    async (kind) => {
      const data = record();
      if (kind === "wrong_account") data.therapist_id = "b";
      if (kind === "old_version") data.accepted_version = "old";
      if (kind === "revoked") {
        data.status = "revoked";
        data.revoked_at = "2026-10-15T11:00:00Z";
      }
      if (kind === "missing_timestamp") data.accepted_at = null;
      const s = new ConsentStore(async () => ({ data, error: null }), true);
      s.setAccount("a");
      await expect(s.require("a", "terms_privacy")).rejects.toThrow();
    },
  );
  it("waits for acknowledgement and retries a failed persistence explicitly", async () => {
    let release!: (v: { data: unknown; error: unknown }) => void;
    const rpc = vi
      .fn()
      .mockRejectedValueOnce(new Error("network"))
      .mockImplementationOnce(
        () =>
          new Promise((r) => {
            release = r;
          }),
      );
    const s = new ConsentStore(rpc, true);
    s.setAccount("a");
    await expect(
      s.decide("a", "terms_privacy", "accepted"),
    ).rejects.toMatchObject({ code: "consent_persist" });
    let done = false;
    const pending = s.decide("a", "terms_privacy", "accepted").then(() => {
      done = true;
    });
    await Promise.resolve();
    expect(done).toBe(false);
    release({ data: record(), error: null });
    await pending;
    expect(rpc.mock.calls[0]).toEqual(rpc.mock.calls[1]);
  });
  it("rejects a pending lookup after account switch/logout", async () => {
    let release!: (v: { data: unknown; error: unknown }) => void;
    const s = new ConsentStore(
      () =>
        new Promise((r) => {
          release = r;
        }),
      true,
    );
    s.setAccount("a");
    const pending = s.lookup("a", "terms_privacy");
    s.setAccount("b");
    release({ data: record(), error: null });
    await expect(pending).rejects.toMatchObject({ code: "stale" });
    s.setAccount(null);
    await expect(s.lookup("b", "terms_privacy")).rejects.toMatchObject({
      code: "stale",
    });
  });
  it("rechecks revoked/declined server decisions instead of caching acceptance", async () => {
    const rpc = vi
      .fn()
      .mockResolvedValueOnce({ data: record(), error: null })
      .mockResolvedValueOnce({
        data: record("terms_privacy", "revoked"),
        error: null,
      })
      .mockResolvedValueOnce({
        data: record("terms_privacy", "declined"),
        error: null,
      });
    const s = new ConsentStore(rpc, true);
    s.setAccount("a");
    await s.require("a", "terms_privacy");
    await expect(s.require("a", "terms_privacy")).rejects.toMatchObject({
      code: "consent",
    });
    await expect(s.require("a", "terms_privacy")).rejects.toMatchObject({
      code: "consent",
    });
  });
  it("invalidates a pre-revocation lookup even within the same account", async () => {
    let release!: (v: { data: unknown; error: unknown }) => void;
    const rpc = vi
      .fn()
      .mockImplementationOnce(
        () =>
          new Promise((r) => {
            release = r;
          }),
      )
      .mockResolvedValueOnce({
        data: record("clinical_text_processing", "revoked"),
        error: null,
      });
    const s = new ConsentStore(rpc, true);
    s.setAccount("a");
    const pending = s.lookup("a", "clinical_text_processing");
    await s.decide("a", "clinical_text_processing", "revoked");
    release({ data: record("clinical_text_processing"), error: null });
    await expect(pending).rejects.toMatchObject({ code: "stale" });
  });
});
