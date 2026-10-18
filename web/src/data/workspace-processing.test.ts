import { beforeEach, expect, it, vi } from "vitest";
const mocks = vi.hoisted(() => ({ invoke: vi.fn(), require: vi.fn(), refuse: vi.fn(), lookup: vi.fn(), snapshot: vi.fn() }));
vi.mock("./client", () => ({ supabase: { functions: { invoke: mocks.invoke }, auth: { getUser: async () => ({ data: { user: { id: "a", is_anonymous: false, app_metadata: { provider: "email" } } } }) } } }));
vi.mock("./consent", () => ({ consents: { ...mocks, setAccount: vi.fn() } }));
vi.mock("../domain/privacy", () => ({ names: { redact: (_storage: unknown, _id: unknown, text: string) => text }, therapistAllowed: () => true }));
import { setApiIdentity, workspaceClinicalAnonymizer } from "./api";
beforeEach(() => {
  vi.resetAllMocks(); vi.stubGlobal("localStorage", {}); vi.stubEnv("VITE_SERVER_CONSENT_ENABLED", "true");
  setApiIdentity(null); setApiIdentity("a");
  mocks.snapshot.mockReturnValue({ record: { status: "required" } });
  mocks.invoke.mockImplementation(async (name: string) => ({ data: name === "get-app-context" ? { entitlement: { access: "full" } } : { anonymizedText: "safe" } }));
});
it.each([true, false])("keeps the existing anonymizer for consent flag %s with unchanged payload", async enabled => {
  vi.stubEnv("VITE_SERVER_CONSENT_ENABLED", String(enabled));
  const anonymize = await workspaceClinicalAnonymizer("a");
  expect(await anonymize("original notes")).toBe("safe");
  expect(mocks.invoke).toHaveBeenLastCalledWith("anonymize-clinical-text", { body: { text: "original notes", therapistIdentifiers: [] } });
  expect(mocks.require).toHaveBeenCalledWith("a", "clinical_text_processing");
  expect(mocks.require).not.toHaveBeenCalledWith("a", "ai_data_sharing");
});
