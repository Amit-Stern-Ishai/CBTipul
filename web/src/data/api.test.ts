import { beforeEach, describe, expect, it, vi } from "vitest";
const fake = vi.hoisted(() => ({
  invoke: vi.fn(),
  getUser: vi.fn(),
  from: vi.fn(),
  rpc: vi.fn(),
}));
vi.mock("./client", () => ({
  supabase: {
    functions: { invoke: fake.invoke },
    auth: { getUser: fake.getUser },
    from: fake.from,
    rpc: fake.rpc,
  },
}));
import { api, setApiIdentity } from "./api";
beforeEach(() => {
  vi.resetAllMocks();
  setApiIdentity(null);
  setApiIdentity("account-a");
  fake.getUser.mockResolvedValue({
    data: { user: { id: "account-a", is_anonymous: false } },
    error: null,
  });
  fake.invoke.mockImplementation(async (name: string) => ({
    data:
      name === "get-app-context"
        ? { role: "therapist", entitlement: { access: "full" } }
        : {},
    error: null,
  }));
});
describe("write authorization and account boundaries", () => {
  it.each([
    { role: "patient", entitlement: { access: "full" } },
    { role: "therapist", entitlement: { access: "read_only" } },
    { role: "therapist", entitlement: null },
  ])("blocks creation under %j", async (context) => {
    fake.invoke.mockResolvedValue({ data: context, error: null });
    await expect(api.createPatient(true)).rejects.toThrow();
    expect(fake.from).not.toHaveBeenCalled();
  });
  it("blocks a pending write after account replacement", async () => {
    let resolve!: (value: unknown) => void;
    fake.invoke.mockReturnValue(
      new Promise((r) => {
        resolve = r;
      }),
    );
    const request = api.createPatient(true);
    await vi.waitFor(() => expect(fake.invoke).toHaveBeenCalled());
    setApiIdentity("account-b");
    resolve({
      data: { role: "therapist", entitlement: { access: "full" } },
      error: null,
    });
    await expect(request).rejects.toThrow();
    expect(fake.from).not.toHaveBeenCalled();
  });
  it("uses a server-generated patient ID and sends no names", async () => {
    const single = vi.fn().mockResolvedValue({
      data: { id: "server-id", active: true, notes: null, formulation: null },
      error: null,
    });
    const select = vi.fn().mockReturnValue({ single });
    const insert = vi.fn().mockReturnValue({ select });
    fake.from.mockReturnValue({ insert });
    expect(await api.createPatient(true)).toMatchObject({ id: "server-id" });
    expect(fake.from).toHaveBeenCalledWith("Patients");
    expect(insert).toHaveBeenCalledWith({ active: true });
  });
});
describe("ongoing assignments", () => {
  it("checks active assignment after the exact existing function succeeds, ignoring completed_at", async () => {
    const assignment = {
      id: "a",
      patient_id: "p",
      type: "questionnaire",
      session_id: null,
      cancelled_at: null,
      completed_at: "2026-10-01",
    };
    const select = vi.fn();
    const query = {
      order: () => query,
      range: () => query,
      eq: () => query,
      then: (resolve: (value: unknown) => unknown) =>
        Promise.resolve({ data: [assignment], count: 1, error: null }).then(
          resolve,
        ),
    };
    select.mockReturnValue(query);
    fake.from.mockReturnValue({ select });
    fake.rpc.mockResolvedValue({ data: true, error: null });
    const result = await api.activate("p", "questionnaire");
    expect(result.id).toBe("a");
    expect(fake.invoke).toHaveBeenCalledWith("request-patient-questionnaire", {
      body: { patientId: "p" },
    });
  });
  it("does not report activation success when no active row exists", async () => {
    const query = {
      order: () => query,
      range: () => query,
      eq: () => query,
      then: (resolve: (value: unknown) => unknown) =>
        Promise.resolve({ data: [], count: 0, error: null }).then(resolve),
    };
    fake.from.mockReturnValue({ select: () => query });
    fake.rpc.mockResolvedValue({ data: true, error: null });
    await expect(api.activate("p", "diary_1")).rejects.toThrow();
    expect(fake.invoke).toHaveBeenCalledWith("request-patient-diary-one", {
      body: { patientId: "p" },
    });
  });
});
