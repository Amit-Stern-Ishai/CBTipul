import { it, expect, vi, beforeEach } from "vitest";
const mock = vi.hoisted(() => ({ owner: "one", invoke: vi.fn() }));
vi.mock("./client", () => ({
  supabase: { functions: { invoke: mock.invoke } },
}));
vi.mock("./api", () => ({
  guard: async () => () => {},
  workspaceAccount: () => mock.owner,
  ApiError: class extends Error {
    constructor(public code: string) {
      super(code);
    }
  },
}));
import {
  exposureBody,
  exposureRequest,
  moveExposure,
  validExposure,
} from "./exposureHierarchy";
const a = {
    id: "11111111-1111-4111-8111-111111111111",
    situation: "מצב א",
    difficulty: null,
  },
  b = {
    id: "22222222-2222-4222-8222-222222222222",
    situation: "מצב ב",
    difficulty: 0,
  },
  c = {
    id: "33333333-3333-4333-8333-333333333333",
    situation: "מצב ג",
    difficulty: 90,
  };
beforeEach(() => {
  mock.owner = "one";
  mock.invoke.mockReset();
});
it("round trips null, zero and manual order without sorting or mutating the baseline", () => {
  const original = { items: [c, b, a] };
  const moved = moveExposure(original, a.id, 0);
  expect(moved.items).toEqual([a, c, b]);
  expect(original.items).toEqual([c, b, a]);
  expect(
    JSON.parse(JSON.stringify(exposureBody("save", null, null, moved))),
  ).toEqual({
    action: "save",
    expected_revision: null,
    document: { items: [a, c, b] },
  });
  expect(exposureBody("load", "p", null, original)).toEqual({
    action: "load",
    patient_id: "p",
  });
});
it("rejects duplicate IDs, blank situations, oversized lists and invalid ratings", () => {
  expect(validExposure({ items: [] })).toBe(true);
  for (const items of [
    [a, a],
    [{ ...a, situation: " " }],
    [{ ...a, situation: "א".repeat(1001) }],
    Array(101).fill(a),
    ...[101, -1, 1.5].map((difficulty) => [{ ...a, difficulty }]),
  ])
    expect(validExposure({ items })).toBe(false);
});
it("returns the saved order and opaque revision", async () => {
  mock.invoke.mockResolvedValue({
    data: {
      patient_id: "p",
      document: { items: [c, b, a] },
      revision: "opaque",
      updated_at: null,
    },
    error: null,
  });
  expect(
    (await exposureRequest("save", "p", "old", { items: [c, b, a] })).document
      ?.items,
  ).toEqual([c, b, a]);
  expect(mock.invoke).toHaveBeenCalledWith("patient-exposure-hierarchy", {
    body: {
      action: "save",
      patient_id: "p",
      expected_revision: "old",
      document: { items: [c, b, a] },
    },
  });
});
it("does not retry conflicts or access failures and leaves input intact", async () => {
  const draft = { items: [a, b] };
  for (const [status, error, code] of [
    [409, "revision_conflict", "revision_conflict"],
    [403, "denied", "access"],
  ] as const) {
    mock.invoke.mockResolvedValue({
      error: { context: { status, json: async () => ({ error }) } },
    });
    await expect(
      exposureRequest("save", "p", "old", draft),
    ).rejects.toMatchObject({ code });
  }
  expect(draft.items).toEqual([a, b]);
  expect(mock.invoke).toHaveBeenCalledTimes(2);
});
it("rejects stale account and wrong patient responses", async () => {
  mock.invoke.mockImplementationOnce(async () => {
    mock.owner = "two";
    return { data: null, error: null };
  });
  await expect(
    exposureRequest("load", "p", null, { items: [] }),
  ).rejects.toMatchObject({ code: "stale" });
  mock.invoke.mockResolvedValue({
    data: { patient_id: "other", document: null, revision: null },
    error: null,
  });
  await expect(
    exposureRequest("load", "p", null, { items: [] }),
  ).rejects.toThrow();
});
