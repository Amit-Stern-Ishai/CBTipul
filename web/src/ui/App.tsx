import { he } from "../he";
import { useEffect, useState, type ReactNode } from "react";
import {
  createBrowserRouter,
  RouterProvider,
  NavLink,
  Outlet,
  Navigate,
  Link,
  useLocation,
  useNavigate,
} from "react-router-dom";
import {
  QueryClient,
  QueryClientProvider,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import {
  LogOut,
  UsersRound,
  CalendarDays,
  Bell,
  Sparkles,
  Settings,
  ArrowUpRight,
} from "lucide-react";
import { AuthProvider, useAuth } from "../auth/Auth";
import { ProfileGate } from "../auth/Profile";
import { Login } from "../auth/Login";
import { therapistAllowed, names } from "../domain/privacy";
import { api } from "../data/api";
import { useContextAccess } from "./hooks";
import { Loading, ErrorBox, Heading } from "./shared";
import legal from "../legal-he.json";
import { PatientsPage, PatientPage, PatientEdit } from "./Patients";
import { SessionsPage, SessionEditor } from "./Sessions";
import {
  QuestionnairesPage,
  QuestionnaireForm,
  QuestionnaireDetail,
} from "./Questionnaires";
import { DiariesPage, DiaryDetail } from "./Diaries";
import { AiPage, PreparationPage } from "./Ai";
import { NotificationsPage, MessagesPage, notificationTarget } from "./Inbox";
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
      refetchOnWindowFocus: true,
      gcTime: 300_000,
    },
    mutations: { retry: false },
  },
});
function Gate() {
  const { session, ready, logout } = useAuth();
  const access = useContextAccess(true);
  const [accepted, setAccepted] = useState<string | null>(null);
  const id = session?.user.id;
  const terms =
    id && localStorage.getItem(`cbtipul.terms.${id}`) === "2026-08-29";
  if (!ready) return <Loading />;
  if (!session) return <Navigate to="/login" replace />;
  if (session.user.is_anonymous) return <Denied logout={logout} />;
  if (access.isPending) return <Loading />;
  if (access.isError && !access.data)
    return (
      <div className="gate">
        <ErrorBox error={access.error} retry={() => void access.refetch()} />
        <button onClick={() => void logout()}>{he.Profile001}</button>
      </div>
    );
  if (!therapistAllowed(session.user, access.data ?? null))
    return <Denied logout={logout} />;
  if (!terms && accepted !== id)
    return (
      <main className="gate legal">
        <h1>{he.App001}</h1>
        <p>{he.App002}</p>
        <details open>
          <summary>{he.Login024}</summary>
          <p className="prose">{legal.termsBody}</p>
        </details>
        <details>
          <summary>{he.Login025}</summary>
          <p className="prose">{legal.privacyBody}</p>
        </details>
        <button
          onClick={() => {
            localStorage.setItem(`cbtipul.terms.${id}`, "2026-08-29");
            setAccepted(id ?? null);
          }}
        >
          {he.App003}
        </button>
        <button className="secondary" onClick={() => void logout()}>
          {he.Profile001}
        </button>
      </main>
    );
  return (
    <ProfileGate key={id}>
      <Shell />
    </ProfileGate>
  );
}
function Denied({ logout }: { logout: () => Promise<void> }) {
  return (
    <main className="gate">
      <h1>{he.App004}</h1>
      <p>{he.App005}</p>
      <button onClick={() => void logout()}>{he.Profile001}</button>
    </main>
  );
}
function Shell() {
  const { logout, session } = useAuth();
  const access = useContextAccess();
  const inbox = useQuery({
    queryKey: [session!.user.id, "notifications"],
    queryFn: api.notifications,
    refetchInterval: 60_000,
    refetchIntervalInBackground: false,
  });
  const count = inbox.data?.filter((x) => !x.seen_at).length ?? 0;
  return (
    <div className="app">
      <aside className="sidebar">
        <Link to="/patients" className="brand">
          <img src="/brand.png" alt="" />
          <span>
            CBTipul<small>{he.App006}</small>
          </span>
        </Link>
        <nav aria-label={he.App007}>
          {[
            [UsersRound, "/patients", he.App008],
            [CalendarDays, "/sessions", he.App009],
            [Sparkles, "/ai", he.Ai001],
            [Bell, "/notifications", he.App010],
            [Settings, "/settings", he.App011],
          ].map(([Icon, to, label]) => {
            const Glyph = Icon as typeof UsersRound;
            return (
              <NavLink key={String(to)} to={String(to)}>
                <Glyph size={20} />
                <span>{String(label)}</span>
                {to === "/notifications" && count > 0 && (
                  <b className="count">{count}</b>
                )}
              </NavLink>
            );
          })}
        </nav>
        <div className="sidebar-bottom">
          <p>
            {he.App012}
            <br />
            {he.App013}
          </p>
          <button className="text-button" onClick={() => void logout()}>
            <LogOut size={18} />
            {he.Profile001}
          </button>
        </div>
      </aside>
      <div className="workspace">
        <div className="topbar">
          <span>{he.App014}</span>
          <a href="https://cbtipul.com" target="_blank" rel="noreferrer">
            {he.App015}
            <ArrowUpRight size={14} />
          </a>
        </div>
        {(access.isError || access.data?.entitlement?.access !== "full") && (
          <div className="readonly">{he.App016}</div>
        )}
        <main id="main-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
function LegalPage() {
  const l = useLocation();
  return (
    <main className="gate legal">
      <Link to="/login">{he.Login022}</Link>
      <h1>{l.pathname.endsWith("privacy") ? he.Login025 : he.Login024}</h1>
      <p className="prose">
        {l.pathname.endsWith("privacy") ? legal.privacyBody : legal.termsBody}
      </p>
    </main>
  );
}
function Callback() {
  const { session, ready } = useAuth();
  const [timeout, setTimeoutState] = useState(false);
  useEffect(() => {
    const t = window.setTimeout(() => setTimeoutState(true), 12000);
    return () => clearTimeout(t);
  }, []);
  if (ready && session) return <Navigate to="/patients" replace />;
  return timeout ? (
    <main className="gate">
      <ErrorBox error={null} />
      <Link to="/login">{he.Login022}</Link>
    </main>
  ) : (
    <Loading />
  );
}
function SettingsPage() {
  const { session, logout } = useAuth();
  const id = session!.user.id;
  const [consent, setConsent] = useState(
    localStorage.getItem(`cbtipul.ai.${id}`) === "yes",
  );
  const [cleared, setCleared] = useState(false);
  return (
    <>
      <Heading title={he.App011} description={he.App017} />
      <section className="panel">
        <h2>{he.App018}</h2>
        <p className="prose">{legal.aiConsentBody}</p>
        <label className="check">
          <input
            type="checkbox"
            checked={consent}
            onChange={(e) => {
              localStorage.setItem(
                `cbtipul.ai.${id}`,
                e.target.checked ? "yes" : "no",
              );
              setConsent(e.target.checked);
            }}
          />
          {he.App019}
        </label>
      </section>
      <section className="panel">
        <h2>{he.App020}</h2>
        <p>{he.App021}</p>
        <button
          className="secondary"
          onClick={() => {
            names.clear(localStorage, id);
            setCleared(true);
          }}
        >
          {he.App022}
        </button>
        {cleared && <p role="status">{he.App023}</p>}
      </section>
      <section className="panel">
        <h2>{he.App024}</h2>
        <bdi>{session?.user.email}</bdi>
        <p>
          <Link to="/legal/terms">{he.Login024}</Link> ·{" "}
          <Link to="/legal/privacy">{he.Login025}</Link>
        </p>
        <button className="secondary" onClick={() => void logout()}>
          {he.Profile001}
        </button>
      </section>
    </>
  );
}
function LoginRoute() {
  const { session, ready } = useAuth();
  return ready && session ? <Navigate to="/patients" replace /> : <Login />;
}
function NotFound() {
  return (
    <main className="gate">
      <h1>{he.App025}</h1>
      <Link to="/patients">{he.App026}</Link>
    </main>
  );
}
const router = createBrowserRouter([
  { path: "/login", element: <LoginRoute /> },
  { path: "/auth/callback", element: <Callback /> },
  { path: "/auth/reset", element: <Login /> },
  { path: "/legal/:document", element: <LegalPage /> },
  {
    element: <Gate />,
    errorElement: (
      <main className="gate">
        <ErrorBox error={null} />
        <Link to="/patients">{he.App026}</Link>
      </main>
    ),
    children: [
      { path: "/", element: <Navigate to="/patients" replace /> },
      { path: "/patients", element: <PatientsPage /> },
      { path: "/patients/new", element: <PatientEdit /> },
      { path: "/patients/:patientId", element: <PatientPage /> },
      { path: "/patients/:patientId/edit", element: <PatientEdit /> },
      { path: "/sessions", element: <SessionsPage /> },
      { path: "/patients/:patientId/sessions", element: <SessionsPage /> },
      {
        path: "/patients/:patientId/sessions/:sessionId",
        element: <SessionEditor />,
      },
      {
        path: "/patients/:patientId/questionnaires",
        element: <QuestionnairesPage />,
      },
      {
        path: "/patients/:patientId/questionnaires/new",
        element: <QuestionnaireForm />,
      },
      {
        path: "/patients/:patientId/questionnaires/:questionnaireId",
        element: <QuestionnaireDetail />,
      },
      { path: "/patients/:patientId/diaries/:diary", element: <DiariesPage /> },
      {
        path: "/patients/:patientId/diaries/:diary/:entryId",
        element: <DiaryDetail />,
      },
      { path: "/patients/:patientId/messages", element: <MessagesPage /> },
      { path: "/patients/:patientId/prepare", element: <PreparationPage /> },
      { path: "/ai", element: <AiPage /> },
      { path: "/patients/:patientId/ai", element: <AiPage /> },
      { path: "/notifications", element: <NotificationsPage /> },
      { path: "/settings", element: <SettingsPage /> },
    ],
  },
  { path: "*", element: <NotFound /> },
]);
export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <RouterProvider router={router} />
      </AuthProvider>
    </QueryClientProvider>
  );
}
// Shared patient heading resolves only browser-local identity.
export function PatientTitle({
  id,
  children,
}: {
  id: string;
  children?: ReactNode;
}) {
  const { session } = useAuth();
  return (
    <div className="patient-title">
      <Link to={`/patients/${id}`}>
        {names.get(localStorage, session!.user.id, id) || he.Ai004}
      </Link>
      {children}
    </div>
  );
}
export function useReadOnDisplay(valid: boolean) {
  const location = useLocation(),
    client = useQueryClient(),
    navigate = useNavigate();
  const notification = new URLSearchParams(location.search).get("notification");
  useEffect(() => {
    if (!valid || !notification) return;
    let live = true;
    api
      .notifications()
      .then(async (items) => {
        const item = items.find((n) => n.id === notification);
        if (!live || !item || notificationTarget(item) !== location.pathname)
          return false;
        if (!item.read_at) await api.read(item.id);
        return true;
      })
      .then((read) => {
        if (live && read) {
          void client.invalidateQueries({
            predicate: (q) => q.queryKey[1] === "notifications",
          });
          navigate(location.pathname, { replace: true });
        }
      })
      .catch(() => {});
    return () => {
      live = false;
    };
  }, [valid, notification, client, navigate, location.pathname]);
}
