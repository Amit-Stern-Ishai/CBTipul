import { useEffect, useState, type ReactNode } from "react";
import { createBrowserRouter, RouterProvider, Link, Navigate, Outlet, useLocation, useNavigate, useBlocker } from "react-router-dom";
import { QueryClient, QueryClientProvider, useQueryClient } from "@tanstack/react-query";
import { AuthProvider, useAuth } from "../auth/Auth";
import { Login } from "../auth/Login";
import { therapistAllowed, names } from "../domain/privacy";
import { api } from "../data/api";
import { useContextAccess } from "./hooks";
import { Loading, ErrorBox } from "./shared";
import { Workspace } from "../workspace/Workspace";
import { notificationTarget } from "./Inbox";
import { he } from "../he";
import legal from "../legal-he.json";
import { SiteHeader, SiteFooter } from "./SiteChrome";
import { ConsentBoundary } from "./ConsentBoundary";
import { unsaved } from "../domain/dirty";
import nav from "../site-navigation.json";

const queryClient = new QueryClient({ defaultOptions: { queries: { staleTime: 30_000, retry: 1, refetchOnWindowFocus: true, gcTime: 300_000 }, mutations: { retry: false } } });

function Gate() {
  const { session, ready, logout } = useAuth();
  const access = useContextAccess(true);
  const id = session?.user.id;
  if (!ready) return <Loading />;
  if (!session) return <Navigate to="/login" replace />;
  if (session.user.is_anonymous) return <Denied logout={logout} />;
  if (access.isPending) return <Loading />;
  if (access.isError && !access.data) return <main className="gate"><ErrorBox error={access.error} retry={() => void access.refetch()} /><button onClick={() => void logout()}>{he.Profile001}</button></main>;
  if (!therapistAllowed(session.user, access.data ?? null)) return <Denied logout={logout} />;
  return <ConsentBoundary key={id} account={id!} type="terms_privacy" title={he.App001} description={he.App002} accept={he.App003} decline={logout} declineLabel={he.Profile001} wording={<><details open><summary>{he.Login024}</summary><p className="prose">{legal.termsBody}</p></details><details><summary>{he.Login025}</summary><p className="prose">{legal.privacyBody}</p></details></>}><Outlet context={{ account: id, canWrite: access.data?.entitlement?.access === "full", logout }} /></ConsentBoundary>;
}
function Denied({ logout }: { logout: () => Promise<void> }) { return <main className="gate"><h1>{he.App004}</h1><p>{he.App005}</p><button onClick={() => void logout()}>{he.Profile001}</button></main>; }
function WorkspaceRoute() {
  const { session, logout } = useAuth();
  const access = useContextAccess();
  if (!session) return null;
  return <Workspace key={session.user.id} account={session.user.id} canWrite={access.data?.entitlement?.access === "full"} logout={logout} />;
}
function LegalPage() { const l = useLocation(); const {session}=useAuth(); return <main className="gate legal"><Link to={session?"/":"/login"}>{session?nav.workspace:he.Login022}</Link><h1>{l.pathname.endsWith("privacy") ? he.Login025 : he.Login024}</h1><p className="prose">{l.pathname.endsWith("privacy") ? legal.privacyBody : legal.termsBody}</p></main>; }
function Callback() {
  const { session, ready } = useAuth();
  const [timeout, setTimeoutState] = useState(false);
  useEffect(() => { const t = window.setTimeout(() => setTimeoutState(true), 12000); return () => clearTimeout(t); }, []);
  if (ready && session) return <Navigate to="/" replace />;
  return timeout ? <main className="gate"><ErrorBox error={null} /><Link to="/login">{he.Login022}</Link></main> : <Loading />;
}
function LoginRoute() { const { session, ready } = useAuth(); return ready && session ? <Navigate to="/" replace /> : <Login />; }
function SiteLayout() {
  const location = useLocation();
  const blocker = useBlocker(({ currentLocation,nextLocation }) => unsaved.active && currentLocation.pathname !== nextLocation.pathname);
  useEffect(() => { if (blocker.state === "blocked") { if(window.confirm(nav.leave)) blocker.proceed(); else blocker.reset(); } },[blocker]);
  return <div className="cb-app-shell"><SiteHeader workspace path={"/app" + (location.pathname === "/" ? "/" : location.pathname)} /><div className="cb-app-content" id="content" tabIndex={-1}><Outlet /></div><SiteFooter path={"/app"+location.pathname} /></div>;
}
const router = createBrowserRouter([{ element: <SiteLayout />, children: [
  { path: "/login", element: <LoginRoute /> },
  { path: "/auth/callback", element: <Callback /> },
  { path: "/auth/reset", element: <Login /> },
  { path: "/legal/:document", element: <LegalPage /> },
  { element: <Gate />, children: [{ path: "/", element: <WorkspaceRoute /> }, { path: "*", element: <Navigate to="/" replace /> }] },
] }], { basename: import.meta.env.BASE_URL.replace(/\/$/, "") });
export function App() { return <QueryClientProvider client={queryClient}><AuthProvider><RouterProvider router={router} /></AuthProvider></QueryClientProvider>; }

// Legacy components remain in source for now; these exports keep them type-safe,
// but no patient or notification route mounts them in the focused workspace.
export function PatientTitle({ id, children }: { id: string; children?: ReactNode }) {
  const { session } = useAuth();
  return <div className="patient-title"><Link to={`/patients/${id}`}>{names.get(localStorage, session!.user.id, id) || he.Ai004}</Link>{children}</div>;
}
export function useReadOnDisplay(valid: boolean) {
  const location = useLocation(), client = useQueryClient(), navigate = useNavigate();
  const notification = new URLSearchParams(location.search).get("notification");
  useEffect(() => {
    if (!valid || !notification) return;
    let live = true;
    api.notifications().then(async (items) => {
      const item = items.find((n) => n.id === notification);
      if (!live || !item || notificationTarget(item) !== location.pathname) return false;
      if (!item.read_at) await api.read(item.id);
      return true;
    }).then((read) => { if (live && read) { void client.invalidateQueries({ predicate: (q) => q.queryKey[1] === "notifications" }); navigate(location.pathname, { replace: true }); } }).catch(() => {});
    return () => { live = false; };
  }, [valid, notification, client, navigate, location.pathname]);
}
