import { he } from "../he";
import { useEffect, useState, type FormEvent } from "react";
import { Link, useParams } from "react-router-dom";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  BookOpen,
  Activity,
  Bell,
  MessageCircle,
  UserRound,
} from "lucide-react";
import { api } from "../data/api";
import { useAuth } from "../auth/Auth";
import { names } from "../domain/privacy";
import type { InboxItem } from "../domain/types";
import { Heading, Loading, ErrorBox, Empty, date, DirtyGuard } from "./shared";
import { PatientBreadcrumb } from "./Patients";
import { useAction, useWrite } from "./hooks";
export function notificationTarget(n: InboxItem): string | null {
  if (!n.patient_id) return null;
  const base = `/patients/${n.patient_id}`;
  if (n.type === "patient_connected") return base;
  const match = n.type.match(/^diary_([123])_entry_added$/);
  if (match && n.resource_id)
    return `${base}/diaries/${match[1]}/${n.resource_id}`;
  if (n.type === "questionnaire_completed" && n.resource_id)
    return `${base}/questionnaires/${n.resource_id}`;
  return null;
}
export function NotificationsPage() {
  const { session } = useAuth(),
    client = useQueryClient();
  const rows = useQuery({
    queryKey: [session!.user.id, "notifications"],
    queryFn: api.notifications,

    refetchIntervalInBackground: false,
  });
  useEffect(() => {
    if (!rows.data?.some((n) => !n.seen_at)) return;
    void api
      .seen()
      .then(() =>
        client.invalidateQueries({
          queryKey: [session!.user.id, "notifications"],
        }),
      )
      .catch(() => {});
  }, [rows.data, session, client]);
  return (
    <>
      <Heading title={he.App010} description={he.Inbox001} />
      {rows.isPending ? (
        <Loading />
      ) : rows.isError ? (
        <ErrorBox error={rows.error} retry={() => void rows.refetch()} />
      ) : !rows.data.length ? (
        <Empty>{he.Inbox002}</Empty>
      ) : (
        <div className="list panel">
          {rows.data.map((n) => {
            const target = notificationTarget(n);
            const questionnaire = n.type === "questionnaire_completed",
              diary = n.type.startsWith("diary_");
            const Icon = questionnaire
              ? Activity
              : diary
                ? BookOpen
                : n.type === "patient_connected"
                  ? UserRound
                  : Bell;
            const body = (
              <>
                <span className="icon-tile">
                  <Icon />
                </span>
                <div>
                  <strong>
                    {n.patient_id
                      ? names.get(
                          localStorage,
                          session!.user.id,
                          n.patient_id,
                        ) || he.Ai004
                      : he.Inbox003}
                  </strong>
                  <p>
                    {questionnaire
                      ? he.Inbox004
                      : diary
                        ? he.Inbox005
                        : n.type === "patient_connected"
                          ? he.Inbox006
                          : he.Inbox007}
                  </p>
                  <small>{date(n.created_at)}</small>
                  {!target && <p>{he.Inbox008}</p>}
                </div>
                {!n.read_at && (
                  <span className="unread-dot" aria-label={he.Inbox009} />
                )}
                {target && (
                  <span className="card-link">
                    {questionnaire
                      ? he.Inbox010
                      : diary
                        ? he.Inbox011
                        : he.Inbox012}
                  </span>
                )}
              </>
            );
            return target ? (
              <Link
                className="list-row"
                key={n.id}
                to={`${target}?notification=${encodeURIComponent(n.id)}`}
              >
                {body}
              </Link>
            ) : (
              <div className="list-row" key={n.id}>
                {body}
              </div>
            );
          })}
        </div>
      )}
    </>
  );
}
export function MessagesPage() {
  const { patientId: id = "" } = useParams(),
    { session } = useAuth(),
    write = useWrite();
  const [text, setText] = useState("");
  const messages = useQuery({
    queryKey: [session!.user.id, "messages", id],
    queryFn: () => api.messages(id),
    refetchInterval: 60_000,
    refetchIntervalInBackground: false,
  });
  const connected = useQuery({
    queryKey: [session!.user.id, "connection", id],
    queryFn: () => api.connected(id),
  });
  const send = useAction(() => api.sendMessage(id, text));
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (send.isPending) return;
    try {
      await send.mutateAsync();
      setText("");
    } catch {
      /* inline */
    }
  }
  return (
    <>
      <PatientBreadcrumb id={id} title={he.Inbox013} />
      <Heading title={he.Inbox013} description={he.Inbox014} />
      <DirtyGuard dirty={!!text} />
      <form className="panel" onSubmit={submit}>
        <label>
          {he.Inbox015}
          <textarea
            rows={4}
            maxLength={4000}
            value={text}
            onChange={(e) => setText(e.target.value)}
            disabled={!write || !connected.data}
            placeholder={he.Inbox016}
          />
        </label>
        <div className="editor-footer">
          <span>{!connected.data ? he.Inbox017 : `${text.length} / 4000`}</span>
          <button
            disabled={
              !write || !connected.data || !text.trim() || send.isPending
            }
          >
            {send.isPending ? he.Inbox018 : he.Inbox019}
          </button>
        </div>
        {send.isError && <ErrorBox error={send.error} />}
      </form>
      <h2>{he.Inbox020}</h2>
      {messages.isPending ? (
        <Loading />
      ) : messages.isError ? (
        <ErrorBox error={messages.error} />
      ) : !messages.data.length ? (
        <Empty>{he.Inbox021}</Empty>
      ) : (
        messages.data.map((m) => (
          <article className="panel" key={m.id}>
            <div className="section-heading">
              <MessageCircle size={20} />
              <small>
                {date(m.created_at)} · {m.read_at ? he.Inbox022 : he.Inbox023}
              </small>
            </div>
            <p className="prose">{m.body}</p>
          </article>
        ))
      )}
    </>
  );
}
