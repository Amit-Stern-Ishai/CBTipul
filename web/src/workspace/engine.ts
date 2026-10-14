import { supabase } from "../data/client";
import { workspaceIdentityMatches } from "../data/api";
import { anonymizeWorkspacePayload } from "./anonymize";
import type { WorkspaceEnvelope, WorkspacePayload } from "./model";
import { finishProblems } from "./model";

export type RpcName = "get_active_web_workspace" | "begin_web_workspace" | "renew_web_workspace_lease" | "save_web_workspace" | "finish_web_workspace" | "discard_web_workspace";
export type Rpc = (name: RpcName, params?: Record<string, unknown>) => Promise<unknown>;
export type Anonymize = (payload: WorkspacePayload, account: string) => Promise<WorkspacePayload>;

export class WorkspaceError extends Error {
  constructor(public code: string) { super(code); }
}
const known = ["workspace_in_use", "lease_lost", "revision_conflict", "read_only", "unauthorized", "therapist_access_required", "workspace_closed", "workspace_not_found", "invalid_workspace", "invalid_item", "invalid_answers", "invalid_diary", "invalid_diary_three", "invalid_thinking_errors", "empty_workspace", "too_many_items", "label_too_long", "consent", "quota", "access", "stale", "anonymization_shape"];
export function classify(error: unknown): WorkspaceError {
  if (error instanceof WorkspaceError) return error;
  const code = error && typeof error === "object" && "code" in error && typeof error.code === "string" ? error.code : "";
  if (known.includes(code)) return new WorkspaceError(code === "anonymization_shape" ? "anonymization" : code);
  const message = error && typeof error === "object" && "message" in error && typeof error.message === "string" ? error.message : "";
  const matched = known.find((value) => message.includes(value));
  return new WorkspaceError(matched === "anonymization_shape" ? "anonymization" : matched ?? "network");
}
export const workspaceRpc: Rpc = async (name, params) => {
  const { data, error } = await supabase.rpc(name, params ?? {});
  if (error) throw classify(error);
  return data;
};

type SaveRequest = { workspaceId: string; token: string; revision: number; version: number; payload: WorkspacePayload };
type FinishRequest = { workspaceId: string; token: string; revision: number; label: string | null };
type FinishMarker = { workspaceId: string; revision: number };
export type Phase = "loading" | "start" | "resume" | "locked" | "editing" | "lost" | "conflict" | "finish_error" | "finish_unconfirmed" | "success" | "error";
export type SaveState = "saved" | "saving" | "unsaved" | "offline";
export type WorkspaceViewState = { phase: Phase; save: SaveState; envelope: WorkspaceEnvelope | null; payload: WorkspacePayload | null; error: string | null; reminderAt: number | null; reminderOpen: boolean };

const prefix = "cbtipul.workspace.";
const editorKey = `${prefix}editor`;
const reminderKey = (account: string, id: string) => `${prefix}reminder.${account}.${id}`;
const markerKey = (account: string) => `${prefix}finish-marker.${account}`;
const storageKeys = (storage: Storage) => Array.from({ length: storage.length }, (_, index) => storage.key(index)).filter((key): key is string => key !== null);
function purgeLegacy(storage: Storage) {
  storageKeys(storage).filter((key) => key.startsWith(prefix) &&
    key !== editorKey && !key.startsWith(`${prefix}reminder.`) && !key.startsWith(`${prefix}finish-marker.`))
    .forEach((key) => storage.removeItem(key));
}
export function clearWorkspaceRecovery(account: string, storage: Storage = sessionStorage) {
  purgeLegacy(storage);
  storageKeys(storage).filter((key) => key.startsWith(`${prefix}reminder.${account}.`) || key === markerKey(account))
    .forEach((key) => storage.removeItem(key));
  storage.removeItem(editorKey);
  if (typeof localStorage !== "undefined" && localStorage !== storage) purgeLegacy(localStorage);
}
export function editorId(storage: Storage = sessionStorage) {
  let id = storage.getItem(editorKey);
  if (!id) { id = crypto.randomUUID(); storage.setItem(editorKey, id); }
  return id;
}

export class WorkspaceEngine {
  state: WorkspaceViewState = { phase: "loading", save: "saved", envelope: null, payload: null, error: null, reminderAt: null, reminderOpen: false };
  private pendingSave: SaveRequest | null = null;
  private finishRequest: FinishRequest | null = null;
  private saveTimer: ReturnType<typeof setTimeout> | null = null;
  private saving: Promise<void> | null = null;
  private finishing = false;
  private finishCall: Promise<void> | null = null;
  private stopped = false;
  private editVersion = 0;
  private ackVersion = 0;

  constructor(
    private account: string,
    private rpc: Rpc = workspaceRpc,
    private storage: Storage = sessionStorage,
    private changed: (state: WorkspaceViewState) => void = () => {},
    private anonymize: Anonymize = anonymizeWorkspacePayload,
    private identityMatches: (account: string) => boolean = workspaceIdentityMatches,
  ) {
    purgeLegacy(storage);
    if (typeof localStorage !== "undefined" && localStorage !== storage) purgeLegacy(localStorage);
  }
  private emit(change: Partial<WorkspaceViewState>) { this.state = { ...this.state, ...change }; this.changed(this.state); }
  private readReminder(id: string, started: string) {
    const minimum = Date.parse(started) + 3_600_000;
    const stored = Number(this.storage.getItem(reminderKey(this.account, id)));
    return Number.isFinite(stored) && stored >= minimum ? stored : minimum;
  }
  private readMarker(): FinishMarker | null {
    try {
      const raw = this.storage.getItem(markerKey(this.account));
      const value = raw ? JSON.parse(raw) as FinishMarker : null;
      return value && typeof value.workspaceId === "string" && Number.isInteger(value.revision) ? value : null;
    } catch { return null; }
  }
  private current(id: string, token: string, revision: number) {
    const env = this.state.envelope;
    if (this.stopped || !this.identityMatches(this.account) || this.state.phase !== "editing" ||
      !env || env.id !== id || env.lease_token !== token || env.revision !== revision) throw new WorkspaceError("access");
  }
  private markFailure(error: unknown) {
    const code = classify(error).code;
    if (code === "lease_lost" || code === "workspace_closed" || code === "access" || code === "unauthorized" || code === "stale") this.emit({ phase: "lost", save: "unsaved", error: code });
    else if (code === "revision_conflict") this.emit({ phase: "conflict", save: "unsaved", error: code });
    else this.emit({ save: "offline", error: code });
  }
  async inspect() {
    this.emit({ phase: "loading", error: null });
    try {
      const active = await this.rpc("get_active_web_workspace") as WorkspaceEnvelope | null;
      const marker = this.readMarker();
      if (marker && !active) {
        try {
          const ack = await this.rpc("finish_web_workspace", {
            p_workspace_id: marker.workspaceId, p_lease_token: null,
            p_expected_revision: marker.revision, p_reference_label: null,
          }) as { id: string; status: string };
          if (ack.id !== marker.workspaceId || !["pending", "associated"].includes(ack.status)) throw new WorkspaceError("invalid_ack");
          this.storage.removeItem(markerKey(this.account));
          this.emit({ phase: "success", envelope: null, payload: null, error: null });
        } catch (error) { this.emit({ phase: "finish_unconfirmed", envelope: null, payload: null, error: classify(error).code }); }
        return;
      }
      if (marker && active?.id === marker.workspaceId) {
        this.emit({ phase: "finish_unconfirmed", envelope: active, payload: null, error: null });
        return;
      }
      this.emit({ phase: active ? "resume" : "start", envelope: null, payload: null, error: null });
    } catch (error) { this.emit({ phase: "error", error: classify(error).code }); }
  }
  async begin(takeOver = false) {
    if (this.stopped) return;
    const previous = this.state;
    const previousVersion = this.editVersion;
    const previousAck = this.ackVersion;
    const previousPending = this.pendingSave;
    this.emit({ phase: "loading", error: null });
    try {
      const env = await this.rpc("begin_web_workspace", { p_editor_id: editorId(this.storage), p_take_over: takeOver }) as WorkspaceEnvelope;
      const same = previous.envelope?.id === env.id && previous.payload !== null;
      let payload = env.payload;
      let dirty = false;
      if (same) {
        const old = previous.envelope!;
        if (env.revision === old.revision) {
          payload = previous.payload!;
          dirty = previousVersion > previousAck;
          if (previousPending) this.pendingSave = { ...previousPending, token: env.lease_token! };
        } else if (previousPending && env.revision === previousPending.revision + 1 &&
                   JSON.stringify(env.payload) === JSON.stringify(previousPending.payload)) {
          this.ackVersion = Math.max(previousAck, previousPending.version);
          this.pendingSave = null;
          payload = previous.payload!;
          dirty = previousVersion > this.ackVersion;
        } else if (previousVersion > previousAck) {
          this.pendingSave = null;
          this.emit({ phase: "conflict", envelope: env, payload: previous.payload, save: "unsaved", error: "revision_conflict",
            reminderAt: this.readReminder(env.id, env.started_at) });
          return;
        }
      }
      if (!same) { this.editVersion = 0; this.ackVersion = 0; this.pendingSave = null; }
      const reminderAt = this.readReminder(env.id, env.started_at);
      this.storage.removeItem(markerKey(this.account));
      this.emit({ phase: "editing", envelope: env, payload, save: dirty ? "unsaved" : "saved", error: null,
        reminderAt, reminderOpen: Date.now() >= reminderAt });
      if (dirty) this.scheduleSave();
    } catch (error) {
      const code = classify(error).code;
      this.emit({ phase: code === "workspace_in_use" ? "locked" : "error", error: code });
    }
  }
  update(payload: WorkspacePayload) {
    if (this.state.phase !== "editing" || this.finishing) return;
    this.editVersion++;
    this.emit({ payload, save: "unsaved", error: null });
    this.scheduleSave();
  }
  private scheduleSave() {
    if (this.saveTimer) clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => { void this.flush().catch(() => {}); }, 1_500);
  }
  private async verifyLease(id: string, token: string, revision: number) {
    this.current(id, token, revision);
    const until = await this.rpc("renew_web_workspace_lease", { p_workspace_id: id, p_lease_token: token });
    this.current(id, token, revision);
    this.emit({ envelope: { ...this.state.envelope!, lease_until: String(until) } });
  }
  async flush(): Promise<void> {
    if (this.saveTimer) { clearTimeout(this.saveTimer); this.saveTimer = null; }
    if (this.saving) return this.saving.then(() => this.flush());
    if (this.state.phase !== "editing" || !this.state.envelope || !this.state.payload) throw new WorkspaceError("not_editing");
    const task = async () => {
      while (this.state.phase === "editing" && this.state.envelope && this.state.payload &&
             (this.editVersion > this.ackVersion || this.pendingSave)) {
        const env = this.state.envelope;
        let request = this.pendingSave;
        try {
          if (!request) {
            const version = this.editVersion;
            const snapshot = structuredClone(this.state.payload);
            this.emit({ save: "saving", error: null });
            const safe = await this.anonymize(snapshot, this.account);
            this.current(env.id, env.lease_token!, env.revision);
            await this.verifyLease(env.id, env.lease_token!, env.revision);
            request = { workspaceId: env.id, token: env.lease_token!, revision: env.revision, version, payload: safe };
            this.pendingSave = request;
          } else {
            await this.verifyLease(request.workspaceId, request.token, request.revision);
          }
          this.current(request.workspaceId, request.token, request.revision);
          this.emit({ save: this.editVersion > request.version ? "unsaved" : "saving", error: null });
          const ack = await this.rpc("save_web_workspace", {
            p_workspace_id: request.workspaceId, p_lease_token: request.token,
            p_expected_revision: request.revision, p_payload: request.payload,
          }) as { id: string; revision: number };
          this.current(request.workspaceId, request.token, request.revision);
          if (ack.id !== env.id || ack.revision !== request.revision + 1) throw new WorkspaceError("invalid_ack");
          this.pendingSave = null;
          this.ackVersion = Math.max(this.ackVersion, request.version);
          this.emit({ envelope: { ...this.state.envelope!, revision: ack.revision, payload: request.payload },
            save: this.editVersion > this.ackVersion ? "unsaved" : "saved", error: null });
        } catch (error) {
          this.markFailure(error);
          throw error;
        }
      }
      if (this.state.phase === "editing" && this.editVersion === this.ackVersion && !this.pendingSave) this.emit({ save: "saved", error: null });
    };
    this.saving = task();
    try { await this.saving; } finally { this.saving = null; }
  }
  async renew() {
    if (this.state.phase !== "editing" || !this.state.envelope) return;
    const env = this.state.envelope;
    try {
      const until = await this.rpc("renew_web_workspace_lease", { p_workspace_id: env.id, p_lease_token: env.lease_token });
      if (this.state.envelope?.id === env.id && this.state.phase === "editing") this.emit({ envelope: { ...this.state.envelope, lease_until: String(until) } });
    } catch (error) {
      if (classify(error).code === "lease_lost") this.markFailure(error);
    }
  }
  checkReminder(now = Date.now()) {
    if (this.state.phase === "editing" && this.state.reminderAt !== null && now >= this.state.reminderAt) this.emit({ reminderOpen: true });
  }
  continueReminder(now = Date.now()) {
    if (this.state.phase !== "editing" || !this.state.envelope) return;
    const reminderAt = now + 3_600_000;
    this.storage.setItem(reminderKey(this.account, this.state.envelope.id), String(reminderAt));
    this.emit({ reminderAt, reminderOpen: false });
  }
  async finish(label: string) {
    if (this.finishing) return;
    if (this.finishRequest) return this.retryFinish();
    if (this.state.phase !== "editing" || !this.state.payload || !this.state.envelope) return;
    if (finishProblems(this.state.payload).length) throw new WorkspaceError("incomplete");
    if (label.length > 100) throw new WorkspaceError("label_too_long");
    this.finishing = true;
    try {
      await this.flush();
      const env = this.state.envelope;
      if (this.state.phase !== "editing" || !env || this.editVersion !== this.ackVersion || this.pendingSave) throw new WorkspaceError("not_saved");
      this.current(env.id, env.lease_token!, env.revision);
      this.finishRequest = { workspaceId: env.id, token: env.lease_token!, revision: env.revision, label: label.trim() || null };
      this.storage.setItem(markerKey(this.account), JSON.stringify({ workspaceId: env.id, revision: env.revision }));
      await this.sendFinish();
    } finally { this.finishing = false; }
  }
  async retryFinish() {
    if (!this.finishRequest) return;
    await this.sendFinish();
  }
  async recoverFailedFinish() {
    if (!this.finishRequest || !["lease_lost", "revision_conflict"].includes(this.state.error ?? "")) return;
    this.finishRequest = null;
    this.storage.removeItem(markerKey(this.account));
    await this.begin();
  }
  private async sendFinish() {
    if (this.finishCall) return this.finishCall;
    const task = this.sendFinishOnce();
    this.finishCall = task;
    try { await task; } finally { this.finishCall = null; }
  }
  private async sendFinishOnce() {
    const request = this.finishRequest!;
    try {
      const ack = await this.rpc("finish_web_workspace", {
        p_workspace_id: request.workspaceId, p_lease_token: request.token,
        p_expected_revision: request.revision, p_reference_label: request.label,
      }) as { id: string; status: string };
      if (ack.id !== request.workspaceId || !["pending", "associated"].includes(ack.status)) throw new WorkspaceError("invalid_ack");
      this.storage.removeItem(markerKey(this.account));
      this.storage.removeItem(reminderKey(this.account, request.workspaceId));
      this.finishRequest = null;
      this.pendingSave = null;
      this.editVersion = 0;
      this.ackVersion = 0;
      this.emit({ phase: "success", payload: null, envelope: null, save: "saved", error: null, reminderOpen: false });
    } catch (error) { this.emit({ phase: "finish_error", error: classify(error).code }); throw error; }
  }
  async discard() {
    const env = this.state.envelope;
    if (!env || this.state.phase !== "editing") return;
    if (this.saveTimer) { clearTimeout(this.saveTimer); this.saveTimer = null; }
    if (this.saving) { try { await this.saving; } catch { /* The server still decides whether discard is allowed. */ } }
    try {
      await this.rpc("discard_web_workspace", { p_workspace_id: env.id, p_lease_token: env.lease_token });
      this.storage.removeItem(reminderKey(this.account, env.id));
      this.pendingSave = null;
      this.editVersion = 0;
      this.ackVersion = 0;
      this.emit({ phase: "start", payload: null, envelope: null, save: "saved", error: null, reminderOpen: false });
    } catch (error) { this.emit({ error: classify(error).code }); throw error; }
  }
  async useServerVersion(takeOver = false) {
    const env = this.state.envelope;
    if (!env || this.state.phase !== "conflict") return;
    try {
      const fresh = await this.rpc("begin_web_workspace", { p_editor_id: editorId(this.storage), p_take_over: takeOver }) as WorkspaceEnvelope;
      if (fresh.id !== env.id) throw new WorkspaceError("workspace_closed");
      this.pendingSave = null;
      this.editVersion = 0;
      this.ackVersion = 0;
      this.emit({ phase: "editing", envelope: fresh, payload: fresh.payload, save: "saved", error: null });
    } catch (error) { this.emit({ error: classify(error).code }); }
  }
  dispose() { this.stopped = true; if (this.saveTimer) clearTimeout(this.saveTimer); }
}
