import { describe, expect, it, vi } from "vitest";
import { WorkspaceEngine, WorkspaceError, type Rpc } from "./engine";
import { anonymizeWorkspacePayload, createWorkspaceAnonymizer, type NotesCache } from "./anonymize";
import { createWorksheet, finishProblems, isFormComplete, markComplete, questionnaireFlags, updateItem, type WorkspaceEnvelope, type WorkspacePayload } from "./model";

class MemoryStorage implements Storage {
  private values = new Map<string, string>();
  get length() { return this.values.size; }
  clear() { this.values.clear(); }
  getItem(key: string) { return this.values.get(key) ?? null; }
  key(index: number) { return [...this.values.keys()][index] ?? null; }
  removeItem(key: string) { this.values.delete(key); }
  setItem(key: string, value: string) { this.values.set(key, value); }
}
const makeEngine = (account: string, rpc: Rpc, storage: Storage) => new WorkspaceEngine(account, rpc, storage, () => {}, async (payload) => payload, () => true);
const base = (): WorkspaceEnvelope => ({ id: "workspace-a", status: "active", started_at: "2026-10-14T08:00:00Z", updated_at: "2026-10-14T08:00:00Z", revision: 0, payload: { version: 1, items: [], notes: "" }, lease_token: "lease-a" });
const mock = (env = base()) => {
  let current = structuredClone(env);
  const calls: { name: string; params: Record<string, unknown> }[] = [];
  let loseSaveAck = false;
  let loseFinishAck = false;
  let leaseLost = false;
  const rpc: Rpc = async (name, params = {}) => {
    calls.push({ name, params });
    if (name === "get_active_web_workspace") return current.status === "active" ? structuredClone(current) : null;
    if (name === "begin_web_workspace") { if (leaseLost && !params.p_take_over) throw new WorkspaceError("workspace_in_use"); leaseLost = false; return structuredClone(current); }
    if (name === "renew_web_workspace_lease") { if (leaseLost) throw new WorkspaceError("lease_lost"); return "2026-10-14T10:00:00Z"; }
    if (name === "save_web_workspace") {
      if (leaseLost) throw new WorkspaceError("lease_lost");
      if (current.revision === Number(params.p_expected_revision) + 1 && JSON.stringify(current.payload) === JSON.stringify(params.p_payload)) return { id: current.id, revision: current.revision };
      if (current.revision !== params.p_expected_revision) throw new WorkspaceError("revision_conflict");
      current = { ...current, revision: current.revision + 1, payload: params.p_payload as WorkspacePayload };
      if (loseSaveAck) { loseSaveAck = false; throw new Error("connection lost"); }
      return { id: current.id, revision: current.revision };
    }
    if (name === "finish_web_workspace") {
      if (current.status === "active") { if (current.revision !== params.p_expected_revision) throw new WorkspaceError("revision_conflict"); current = { ...current, status: "pending" }; }
      if (loseFinishAck) { loseFinishAck = false; throw new Error("connection lost"); }
      return { id: current.id, status: "pending" };
    }
    if (name === "discard_web_workspace") { current = { ...current, status: "discarded" }; return null; }
    throw new Error("Unexpected RPC");
  };
  return { rpc, calls, current: () => current, loseSave: () => { loseSaveAck = true; }, loseFinish: () => { loseFinishAck = true; }, loseLease: () => { leaseLost = true; } };
};

describe("workspace format and scoring", () => {
  it("allows incomplete drafts and requires explicit completion or removal", () => {
    const item = createWorksheet("diary_one");
    const draft: WorkspacePayload = { version: 1, notes: "", items: [item] };
    expect(finishProblems(draft)).toEqual([item.id]);
    expect(finishProblems({ ...draft, items: [] })).toEqual(["empty"]);
    expect(isFormComplete(item)).toBe(false);
    const complete = updateItem(item, { data: { event: "מצב", automatic_thoughts: ["מחשבה"], feelings: [{ name: "עצב", intensity: 70 }], behaviour: "תגובה" } });
    expect(isFormComplete(complete)).toBe(true);
    const marked = markComplete(complete, new Date("2026-10-14T09:00:00Z"));
    expect(marked.completed_at).toBe("2026-10-14T09:00:00.000Z");
    expect(finishProblems({ ...draft, items: [marked] })).toEqual([]);
    expect(updateItem(marked, { data: { behaviour: "תגובה אחרת" } }).completed_at).toBeUndefined();
  });
  it("keeps each diary JSON shape and flags PHQ-9 question 9", () => {
    const two = updateItem(createWorksheet("diary_two"), { data: { event: "מצב", automatic_thoughts: ["מחשבה"], feelings: [{ name: "דאגה", intensity: 40 }], thinking_errors: ["all_or_nothing"], alternative_thoughts: ["חלופה"] } });
    const three = updateItem(createWorksheet("diary_three"), { data: { situation: "מצב", automatic_thoughts: [{ text: "מחשבה", beliefBefore: 80, beliefAfter: 30 }], feelings: [{ name: "דאגה", intensityBefore: 80, intensityAfter: 30 }], thinking_errors: ["all_or_nothing"], alternative_thoughts: [{ text: "חלופה", belief: 70 }] } });
    expect(isFormComplete(two)).toBe(true);
    expect(isFormComplete(three)).toBe(true);
    expect((three.data.automatic_thoughts as Record<string, unknown>[])[0]).toEqual({ text: "מחשבה", beliefBefore: 80, beliefAfter: 30 });
    const q = updateItem(createWorksheet("questionnaire", new Date("2026-10-14T23:10:00Z")), { data: { gad7_answers: Array(7).fill(1), phq9_answers: [...Array(8).fill(0), 1], interference_level: 2 } });
    expect(questionnaireFlags(q)).toEqual({ gad: 7, phq: 1, question9: true });
    expect(isFormComplete(q)).toBe(true);
    expect(markComplete(q).measurement_date).toBe(q.measurement_date);
  });
  it("distinguishes an unaddressed thinking-error field from an explicit none selection", () => {
    for (const type of ["diary_two", "diary_three"] as const) {
      const initial = createWorksheet(type);
      expect(initial.data.thinking_errors).toBeNull();
      const data = type === "diary_two"
        ? { event: "מצב", automatic_thoughts: ["מחשבה"], feelings: [{ name: "דאגה", intensity: 40 }], alternative_thoughts: ["חלופה"] }
        : { situation: "מצב", automatic_thoughts: [{ text: "מחשבה", beliefBefore: 80, beliefAfter: 30 }], feelings: [{ name: "דאגה", intensityBefore: 80, intensityAfter: 30 }], alternative_thoughts: [{ text: "חלופה", belief: 70 }] };
      const unaddressed = updateItem(initial, { data });
      expect(isFormComplete(unaddressed)).toBe(false);
      const confirmed = updateItem(unaddressed, { data: { thinking_errors: [] } });
      expect(isFormComplete(confirmed)).toBe(true);
      expect(markComplete(confirmed).data.thinking_errors).toEqual([]);
      expect(isFormComplete(updateItem(confirmed, { data: { thinking_errors: ["made_up"] } }))).toBe(false);
    }
  });
  it("keeps an explicitly empty selection when the current backend rejects finishing it", async () => {
    const backend = mock();
    const rpc: Rpc = (name, params) => name === "finish_web_workspace"
      ? Promise.reject(new WorkspaceError("invalid_thinking_errors"))
      : backend.rpc(name, params);
    const engine = makeEngine("account-a", rpc, new MemoryStorage());
    await engine.inspect(); await engine.begin();
    const diary = createWorksheet("diary_two");
    const complete = markComplete(updateItem(diary, { data: {
      event: "מצב", automatic_thoughts: ["מחשבה"], feelings: [{ name: "דאגה", intensity: 40 }],
      thinking_errors: [], alternative_thoughts: ["חלופה"],
    } }));
    engine.update({ version: 1, notes: "", items: [complete] });
    await expect(engine.finish("")).rejects.toThrow("invalid_thinking_errors");
    expect(engine.state.phase).toBe("finish_error");
    expect(engine.state.payload?.items[0].data.thinking_errors).toEqual([]);
    expect(backend.current().status).toBe("active");
    engine.dispose();
  });
});

describe("workspace reliability", () => {
  it("retries the exact save request before later edits and preserves revision", async () => {
    const backend = mock(), storage = new MemoryStorage();
    const engine = makeEngine("account-a", backend.rpc, storage);
    await engine.inspect(); await engine.begin();
    backend.loseSave();
    engine.update({ version: 1, items: [], notes: "first" });
    await expect(engine.flush()).rejects.toThrow();
    engine.update({ version: 1, items: [], notes: "second" });
    await engine.flush();
    const saves = backend.calls.filter((call) => call.name === "save_web_workspace");
    expect(saves).toHaveLength(3);
    expect(saves[0].params).toEqual(saves[1].params);
    expect(saves[2].params.p_expected_revision).toBe(1);
    expect(backend.current().payload.notes).toBe("second");
    engine.dispose();
  });
  it("stops on revision conflict without overwriting server content", async () => {
    const backend = mock(), engine = makeEngine("account-a", backend.rpc, new MemoryStorage());
    await engine.inspect(); await engine.begin();
    engine.update({ version: 1, items: [], notes: "local" });
    backend.current().revision = 3;
    backend.current().payload = { version: 1, items: [], notes: "server" };
    await expect(engine.flush()).rejects.toThrow();
    expect(engine.state.phase).toBe("conflict");
    expect(engine.state.payload?.notes).toBe("local");
    expect(backend.calls.filter((c) => c.name === "save_web_workspace")).toHaveLength(1);
    await engine.useServerVersion();
    expect(engine.state.phase).toBe("editing");
    expect(engine.state.payload?.notes).toBe("server");
    expect(engine.state.envelope?.revision).toBe(3);
    engine.update({ version: 1, items: [], notes: "new local" });
    await engine.flush();
    expect(backend.current().revision).toBe(4);
    engine.dispose();
  });
  it("requires explicit takeover and stops editing when a lease is lost", async () => {
    const backend = mock(), engine = makeEngine("account-a", backend.rpc, new MemoryStorage());
    await engine.inspect(); backend.loseLease(); await engine.begin();
    expect(engine.state.phase).toBe("locked");
    expect(backend.calls.at(-1)?.params.p_take_over).toBe(false);
    await engine.begin(true); expect(engine.state.phase).toBe("editing");
    backend.loseLease(); await engine.renew(); expect(engine.state.phase).toBe("lost");
    engine.update({ version: 1, items: [], notes: "ignored" });
    expect(engine.state.payload?.notes).toBe("");
    engine.dispose();
  });
  it("keeps original text only in memory and reopens from the acknowledged server snapshot", async () => {
    const backend = mock(), storage = new MemoryStorage();
    storage.setItem("cbtipul.workspace.account-a.workspace-a", JSON.stringify({ payload: { notes: "legacy clinical text" } }));
    storage.setItem("unrelated", "keep");
    const first = new WorkspaceEngine("account-a", backend.rpc, storage, () => {},
      async (payload) => ({ ...payload, notes: "anonymized" }), () => true);
    await first.inspect(); await first.begin(); first.update({ version: 1, items: [], notes: "original" });
    await first.flush(); first.dispose();
    const second = makeEngine("account-a", backend.rpc, storage);
    await second.inspect(); expect(second.state.phase).toBe("resume"); expect(second.state.payload).toBeNull();
    await second.begin(); expect(second.state.payload?.notes).toBe("anonymized");
    const other = makeEngine("account-b", backend.rpc, storage);
    await other.inspect(); await other.begin(); expect(other.state.payload?.notes).toBe("anonymized");
    expect([...Array(storage.length)].map((_, i) => storage.getItem(storage.key(i)!)).join(" ")).not.toContain("original");
    expect([...Array(storage.length)].map((_, i) => storage.getItem(storage.key(i)!)).join(" ")).not.toContain("legacy clinical");
    expect(storage.getItem("unrelated")).toBe("keep");
    second.dispose(); other.dispose();
  });
  it("reminds from started_at and persists the continued interval", async () => {
    const backend = mock(), storage = new MemoryStorage();
    const engine = makeEngine("account-a", backend.rpc, storage);
    vi.setSystemTime(new Date("2026-10-14T09:05:00Z"));
    await engine.inspect(); await engine.begin(); expect(engine.state.reminderOpen).toBe(true);
    engine.continueReminder(Date.parse("2026-10-14T09:05:00Z"));
    expect(engine.state.reminderAt).toBe(Date.parse("2026-10-14T10:05:00Z"));
    engine.dispose();
    const resumed = makeEngine("account-a", backend.rpc, storage);
    await resumed.inspect(); await resumed.begin(); expect(resumed.state.reminderOpen).toBe(false);
    resumed.checkReminder(Date.parse("2026-10-14T10:06:00Z")); expect(resumed.state.reminderOpen).toBe(true);
    resumed.dispose(); vi.useRealTimers();
  });
  it("retains content after uncertain finish and clears only after an acknowledged retry", async () => {
    const backend = mock(), storage = new MemoryStorage();
    const engine = makeEngine("account-a", backend.rpc, storage);
    await engine.inspect(); await engine.begin(); engine.update({ version: 1, items: [], notes: "session notes" });
    backend.loseFinish();
    await expect(engine.finish("code-1")).rejects.toThrow();
    expect(engine.state.phase).toBe("finish_error");
    expect(engine.state.payload?.notes).toBe("session notes");
    const retry = makeEngine("account-a", backend.rpc, storage);
    await retry.inspect(); expect(retry.state.phase).toBe("success"); expect(retry.state.payload).toBeNull();
    const finishes = backend.calls.filter((c) => c.name === "finish_web_workspace");
    expect(finishes).toHaveLength(2);
    expect(finishes[1].params).toEqual({
      p_workspace_id: "workspace-a", p_lease_token: null, p_expected_revision: 1, p_reference_label: null,
    });
    expect([...Array(storage.length)].map((_, i) => storage.getItem(storage.key(i)!)).join(" ")).not.toContain("session notes");
    expect([...Array(storage.length)].map((_, i) => storage.key(i)).filter((k) => k?.includes("account-a"))).toEqual([]);
    engine.dispose(); retry.dispose();
  });
  it("retries the exact finish request while the same tab remains open", async () => {
    const backend = mock(), engine = makeEngine("account-a", backend.rpc, new MemoryStorage());
    await engine.inspect(); await engine.begin(); engine.update({ version: 1, items: [], notes: "original" });
    backend.loseFinish();
    await expect(engine.finish("REF-7")).rejects.toThrow();
    await engine.retryFinish();
    const finishes = backend.calls.filter((call) => call.name === "finish_web_workspace");
    expect(finishes).toHaveLength(2);
    expect(finishes[0].params).toEqual(finishes[1].params);
    expect(engine.state.phase).toBe("success");
    engine.dispose();
  });
});

describe("workspace anonymization and final-save ordering", () => {
  it("anonymizes only notes while preserving every diary field exactly", async () => {
    const q = updateItem(createWorksheet("questionnaire"), { data: { gad7_answers: Array(7).fill(2), phq9_answers: Array(9).fill(1), interference_level: 3, notes: "question note" } });
    const one = updateItem(createWorksheet("diary_one"), { data: { event: "event one", automatic_thoughts: ["thought one"], feelings: [{ name: "sad", intensity: 73 }], behaviour: "behaviour", physical_symptoms: "symptoms" } });
    const two = updateItem(createWorksheet("diary_two"), { data: { event: "event two", automatic_thoughts: ["thought two"], feelings: [{ name: "fear", intensity: 32 }], thinking_errors: ["all_or_nothing"], alternative_thoughts: ["alternative two"] } });
    const three = updateItem(createWorksheet("diary_three"), { data: { situation: "situation", automatic_thoughts: [{ text: "nested thought", beliefBefore: 91, beliefAfter: 26 }], feelings: [{ name: "worry", intensityBefore: 80, intensityAfter: 15 }], thinking_errors: [], alternative_thoughts: [{ text: "nested alternative", belief: 77 }] } });
    const payload: WorkspacePayload = { version: 1, notes: "session note", items: [q, one, two, three] };
    const seen: string[] = [];
    const safe = await anonymizeWorkspacePayload(payload, "account-a", async () => async (value) => {
      seen.push(value);
      return value ? `SAFE:${value}` : "";
    });
    expect(seen).toEqual(["session note", "question note"]);
    expect(safe.items.slice(1)).toEqual(payload.items.slice(1));
    expect(safe.notes).toBe("SAFE:session note");
    expect(safe.items.map((item) => ({ id: item.id, type: item.type, completed_at: item.completed_at, measurement_date: item.measurement_date })))
      .toEqual(payload.items.map((item) => ({ id: item.id, type: item.type, completed_at: item.completed_at, measurement_date: item.measurement_date })));
    expect(safe.items[0].data.gad7_answers).toEqual(Array(7).fill(2));
    expect(safe.items[0].data.phq9_answers).toEqual(Array(9).fill(1));
    expect(safe.items[0].data.interference_level).toBe(3);
    expect((safe.items[3].data.automatic_thoughts as Record<string, unknown>[])[0]).toEqual({ text: "nested thought", beliefBefore: 91, beliefAfter: 26 });
    expect((safe.items[3].data.feelings as Record<string, unknown>[])[0]).toEqual({ name: "worry", intensityBefore: 80, intensityAfter: 15 });
    expect(safe.items[2].data.thinking_errors).toEqual(["all_or_nothing"]);
    expect(safe.items[3].data.thinking_errors).toEqual([]);
    expect(payload.notes).toBe("session note");
    expect((payload.items[3].data.automatic_thoughts as Record<string, unknown>[])[0].text).toBe("nested thought");
  });

  it("fails closed on malformed structure or an unusable anonymization response", async () => {
    const payload: WorkspacePayload = { version: 1, notes: "original", items: [] };
    await expect(anonymizeWorkspacePayload(payload, "account-a", async () => async () => "")).rejects.toThrow("anonymization_shape");
    await expect(anonymizeWorkspacePayload({ ...payload, items: [{ id: "id", type: "diary_one", data: { event: "raw", unknown_text: "must not pass" } }] }, "account-a", async () => async (text) => text)).rejects.toThrow("anonymization_shape");
    const backend = mock(), storage = new MemoryStorage();
    const engine = new WorkspaceEngine("account-a", backend.rpc, storage, () => {}, async (snapshot) =>
      anonymizeWorkspacePayload(snapshot, "account-a", async () => async () => ""), () => true);
    await engine.inspect(); await engine.begin(); engine.update(payload);
    await expect(engine.flush()).rejects.toThrow();
    expect(backend.calls.filter((call) => call.name === "save_web_workspace")).toHaveLength(0);
    expect(engine.state.payload?.notes).toBe("original");
    expect(engine.state.save).toBe("offline");
    expect(JSON.stringify([...Array(storage.length)].map((_, i) => storage.getItem(storage.key(i)!)))).not.toContain("original");
    engine.dispose();
  });

  it("keeps newer edits unsaved while serializing anonymization and server saves", async () => {
    const backend = mock(), states: { save: string; revision: number }[] = [];
    let releaseFirst!: () => void;
    const firstGate = new Promise<void>((resolve) => { releaseFirst = resolve; });
    let enteredFirst!: () => void;
    const entered = new Promise<void>((resolve) => { enteredFirst = resolve; });
    const engine = new WorkspaceEngine("account-a", backend.rpc, new MemoryStorage(),
      (state) => states.push({ save: state.save, revision: state.envelope?.revision ?? -1 }),
      async (payload) => {
        if (payload.notes === "first") { enteredFirst(); await firstGate; }
        return { ...payload, notes: `SAFE:${payload.notes}` };
      }, () => true);
    await engine.inspect(); await engine.begin();
    engine.update({ version: 1, items: [], notes: "first" });
    const saving = engine.flush();
    await entered;
    engine.update({ version: 1, items: [], notes: "second" });
    expect(engine.state.save).toBe("unsaved");
    releaseFirst();
    await saving;
    expect(states).toContainEqual({ save: "unsaved", revision: 1 });
    expect(engine.state.save).toBe("saved");
    expect(engine.state.payload?.notes).toBe("second");
    expect(backend.current().payload.notes).toBe("SAFE:second");
    expect(backend.current().revision).toBe(2);
    engine.dispose();
  });

  it("retries the same anonymized payload after a lost save response", async () => {
    const backend = mock();
    let anonymizations = 0;
    const engine = new WorkspaceEngine("account-a", backend.rpc, new MemoryStorage(), () => {},
      async (payload) => { anonymizations++; return { ...payload, notes: `SAFE:${payload.notes}` }; }, () => true);
    await engine.inspect(); await engine.begin(); backend.loseSave();
    engine.update({ version: 1, items: [], notes: "original" });
    await expect(engine.flush()).rejects.toThrow();
    await engine.flush();
    const saves = backend.calls.filter((call) => call.name === "save_web_workspace");
    expect(saves).toHaveLength(2);
    expect(saves[0].params).toEqual(saves[1].params);
    expect((saves[0].params.p_payload as WorkspacePayload).notes).toBe("SAFE:original");
    expect(anonymizations).toBe(1);
    engine.dispose();
  });

  it("does not save if the lease or account changes during anonymization", async () => {
    for (const change of ["lease", "account"]) {
      const backend = mock();
      let allow = true;
      let release!: () => void;
      const gate = new Promise<void>((resolve) => { release = resolve; });
      let started!: () => void;
      const entered = new Promise<void>((resolve) => { started = resolve; });
      const engine = new WorkspaceEngine("account-a", backend.rpc, new MemoryStorage(), () => {},
        async (payload) => { started(); await gate; return { ...payload, notes: "SAFE" }; },
        () => allow);
      await engine.inspect(); await engine.begin(); engine.update({ version: 1, items: [], notes: "raw" });
      const saving = engine.flush();
      await entered;
      if (change === "lease") backend.loseLease(); else allow = false;
      release();
      await expect(saving).rejects.toThrow();
      expect(backend.calls.filter((call) => call.name === "save_web_workspace")).toHaveLength(0);
      expect(engine.state.payload?.notes).toBe("raw");
      engine.dispose();
    }
  });

  it("finishes only after the latest local edit is anonymized and acknowledged", async () => {
    const backend = mock();
    let release!: () => void;
    const gate = new Promise<void>((resolve) => { release = resolve; });
    let started!: () => void;
    const entered = new Promise<void>((resolve) => { started = resolve; });
    const engine = new WorkspaceEngine("account-a", backend.rpc, new MemoryStorage(), () => {},
      async (payload) => {
        if (payload.notes === "first") { started(); await gate; }
        return { ...payload, notes: `SAFE:${payload.notes}` };
      }, () => true);
    await engine.inspect(); await engine.begin(); engine.update({ version: 1, items: [], notes: "first" });
    const saving = engine.flush(); await entered;
    engine.update({ version: 1, items: [], notes: "latest" });
    const finishing = engine.finish("REF");
    expect(backend.calls.filter((call) => call.name === "finish_web_workspace")).toHaveLength(0);
    release(); await saving; await finishing;
    const calls = backend.calls.map((call) => call.name);
    const finishIndex = calls.lastIndexOf("finish_web_workspace");
    expect(finishIndex).toBeGreaterThan(calls.lastIndexOf("save_web_workspace"));
    expect(backend.current().payload.notes).toBe("SAFE:latest");
    expect(engine.state.phase).toBe("success");
    engine.dispose();
  });
});


describe("diary save acknowledgement", () => {
  const diary = () => updateItem(createWorksheet("diary_one"), { data: { event: '  אמא אמרה: "לא!"\nאבא, ואני…  ', automatic_thoughts: ["זו המחשבה שלי"], feelings: [{ name: "עצבות", intensity: 50 }], behaviour: "נשארתי" } });
  it("waits for the submitted version, preserves text on RPC/reopen and skips unchanged notes", async () => {
    const backend = mock(); const cache: NotesCache = new Map(); const seen: string[] = [];
    const transform = (p: WorkspacePayload, account: string) => anonymizeWorkspacePayload(p, account, async () => async (text) => { seen.push(text); return `SAFE:${text}`; }, cache);
    let release!: () => void; const gate = new Promise<void>((resolve) => { release = resolve; });
    let saveCalls = 0;
    const rpc: Rpc = async (name, params) => { if (name === "save_web_workspace" && ++saveCalls === 2) await gate; return backend.rpc(name, params); };
    const engine = new WorkspaceEngine("a", rpc, new MemoryStorage(), () => {}, transform, () => true);
    await engine.begin(); engine.update({ version: 1, notes: "private note", items: [updateItem(createWorksheet("questionnaire"), { data: { notes: "question note" } })] }); await engine.flush();
    const original = diary(); engine.update({ ...engine.state.payload!, items: [original, ...engine.state.payload!.items] });
    let confirmed = false; const saving = engine.saveWorksheet(original).then(() => { confirmed = true; });
    await vi.waitFor(() => expect(saveCalls).toBe(2)); expect(confirmed).toBe(false);
    release(); await saving; await engine.flush();
    expect(seen).toEqual(["private note", "question note"]);
    expect(backend.current().payload.items[1].data.notes).toBe("SAFE:question note");
    expect(backend.current().payload.items[0].data).toEqual(original.data);
    expect(backend.current().payload.notes).toBe("SAFE:private note");
    const reopen = makeEngine("a", backend.rpc, new MemoryStorage()); await reopen.begin();
    expect(reopen.state.payload?.items[0].data).toEqual(original.data);
    engine.dispose(); reopen.dispose();
  });
  it("acknowledges an earlier diary version without claiming newer edits were saved", async () => {
    const backend = mock(); let first!: () => void; let second!: () => void;
    const gates = [new Promise<void>((r) => { first = r; }), new Promise<void>((r) => { second = r; })];
    let count = 0; const rpc: Rpc = async (name, params) => { if (name === "save_web_workspace") await gates[count++]; return backend.rpc(name, params); };
    const engine = makeEngine("a", rpc, new MemoryStorage()); await engine.begin();
    const original = diary(); engine.update({ version: 1, notes: "", items: [original] });
    const saved = engine.saveWorksheet(original); await vi.waitFor(() => expect(count).toBe(1));
    const newer = updateItem(original, { data: { event: "newer" } }); engine.update({ ...engine.state.payload!, items: [newer] });
    first(); await saved; expect(engine.state.payload?.items[0].data.event).toBe("newer"); expect(engine.state.save).not.toBe("saved");
    second(); await engine.flush(); expect(backend.current().payload.items[0].data.event).toBe("newer"); engine.dispose();
  });
  it.each(["network", "lease_lost"])("rejects pending feedback on %s and retains content", async (code) => {
    const backend = mock(); const rpc: Rpc = async (name, params) => { if (name === "save_web_workspace") throw new WorkspaceError(code); return backend.rpc(name, params); };
    const engine = makeEngine("a", rpc, new MemoryStorage()); await engine.begin();
    const original = diary(); engine.update({ version: 1, notes: "", items: [original] });
    await expect(engine.saveWorksheet(original)).rejects.toThrow(code); expect(engine.state.payload?.items[0].data).toEqual(original.data); engine.dispose();
  });
  it("cancels feedback when disposed during a pending save", async () => {
    const backend = mock(); let release!: () => void; const gate = new Promise<void>((r) => { release = r; });
    const rpc: Rpc = async (name, params) => { if (name === "save_web_workspace") await gate; return backend.rpc(name, params); };
    const engine = makeEngine("a", rpc, new MemoryStorage()); await engine.begin();
    const original = diary(); engine.update({ version: 1, notes: "", items: [original] });
    const saving = engine.saveWorksheet(original); const rejected = expect(saving).rejects.toThrow("cancelled"); engine.dispose(); await rejected; release();
  });
});


it("reuses only unchanged notes, including on reopen, and fails closed on changed notes", async () => {
  const seen: string[] = []; const transform = createWorkspaceAnonymizer(async () => async (text) => { seen.push(text); if (text === "fail") throw new Error("unavailable"); return `SAFE:${text}`; });
  const server: WorkspacePayload = { version: 1, notes: "SAFE:previous note", items: [] };
  transform.seed(server, "a");
  await transform({ ...server, items: [createWorksheet("diary_three")] }, "a"); expect(seen).toEqual([]);
  await transform({ ...server, notes: "changed" }, "a");
  await transform({ ...server, notes: "" }, "a");
  await transform({ ...server, notes: "changed" }, "a"); expect(seen).toEqual(["changed", "changed"]);
  await expect(transform({ ...server, notes: "fail" }, "a")).rejects.toThrow("unavailable");
});


it("retries an identical original-diary snapshot before sending newer diary edits", async () => {
  const backend = mock(); const seen: string[] = [];
  const engine = new WorkspaceEngine("a", backend.rpc, new MemoryStorage(), () => {}, createWorkspaceAnonymizer(async () => async (text) => { seen.push(text); return `SAFE:${text}`; }), () => true);
  await engine.begin();
  const item = updateItem(createWorksheet("diary_one"), { data: { event: '  אמא, אבא—ואני.\n"כן"  ' } });
  engine.update({ version: 1, notes: "note", items: [item] }); backend.loseSave(); await expect(engine.flush()).rejects.toThrow();
  engine.update({ ...engine.state.payload!, items: [updateItem(item, { data: { event: "new wording" } })] }); await engine.flush();
  const saves = backend.calls.filter((call) => call.name === "save_web_workspace");
  expect(saves[0].params).toEqual(saves[1].params);
  expect((saves[0].params.p_payload as WorkspacePayload).items[0].data.event).toBe(item.data.event);
  expect((saves[2].params.p_payload as WorkspacePayload).items[0].data.event).toBe("new wording"); expect(seen).toEqual(["note"]);
  engine.dispose();
});
