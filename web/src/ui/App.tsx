import { useEffect, useState, useRef, type ReactNode } from "react";
import { createBrowserRouter, RouterProvider, Link, Navigate, Outlet, useLocation, useNavigate } from "react-router-dom";
import { QueryClient, QueryClientProvider, useQueryClient } from "@tanstack/react-query";
import { AuthProvider, useAuth } from "../auth/Auth";
import { Login } from "../auth/Login";
import { therapistAllowed, names } from "../domain/privacy";
import { api } from "../data/api";
import { useContextAccess } from "./hooks";
import { Loading, ErrorBox } from "./shared";
import { PatientWorkspace, NamesConsent } from "../workspace/PatientWorkspace";
import { notificationTarget } from "./Inbox";
import { he } from "../he";
import legal from "../legal-he.json";
import { SiteHeader, SiteFooter } from "./SiteChrome";
import { consents } from "../data/consent";
import { useQuery } from "@tanstack/react-query";
import { ConsentBoundary } from "./ConsentBoundary";

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
function WorkspaceRoute() { const {session}=useAuth(); return <NamesConsent><PatientWorkspace key={session!.user.id}/></NamesConsent>; }
function SharedRoute() {
  const [cache]=useState(()=>new QueryClient({defaultOptions:{queries:{retry:1,refetchOnWindowFocus:true},mutations:{retry:false}}}));
  return <QueryClientProvider client={cache}><SharedGate/></QueryClientProvider>;
}
function SharedGate() {
  const {session,ready}=useAuth(), access=useContextAccess(true);
  const consent=useQuery({queryKey:[session?.user.id,'shared-consent'],enabled:!!session,queryFn:async()=>{await consents.require(session!.user.id,'terms_privacy');await consents.require(session!.user.id,'patient_name_storage');return true;},refetchOnWindowFocus:true});
  const firstAccount=useRef<string|null>(null), expired=useRef(false);
  if(!ready)return <Loading/>;
  if(!session || (firstAccount.current && firstAccount.current!==session.user.id))expired.current=true;
  if(session && !firstAccount.current)firstAccount.current=session.user.id;
  if(expired.current)return <main className="pw-neutral"><h1>תוקף התצוגה הסתיים</h1><p>חזרו לחלון הפרטי כדי להתחבר מחדש ולפתוח חלון שיתוף חדש.</p></main>;
  if(access.isPending||consent.isPending)return <Loading/>;
  if(access.isError || consent.isError || !therapistAllowed(session?.user??null,access.data??null))return <main className="pw-neutral"><h1>התצוגה אינה זמינה</h1><p>לא ניתן לאמת הרשאה. חזרו לחלון הפרטי.</p><button onClick={()=>void Promise.allSettled([access.refetch(),consent.refetch()])}>ניסיון נוסף</button></main>;
  return <PatientWorkspace key={session!.user.id} shared/>;
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
  return <div className="cb-app-shell"><SiteHeader workspace path={"/app" + (location.pathname === "/" ? "/" : location.pathname)} /><div className="cb-app-content" id="content" tabIndex={-1}><Outlet /></div><SiteFooter path={"/app"+location.pathname} /></div>;
}
const router = createBrowserRouter([{path:"/shared/:patientId/:section",element:<SharedRoute/>}, { element: <SiteLayout />, children: [
  { path: "/login", element: <LoginRoute /> },
  { path: "/auth/callback", element: <Callback /> },
  { path: "/auth/reset", element: <Login /> },
  { path: "/legal/:document", element: <LegalPage /> },
  { element: <Gate />, children: [{ path: "/", element: <WorkspaceRoute /> }, {path:"/patients/:patientId/:section",element:<WorkspaceRoute/>}, { path: "*", element: <Navigate to="/" replace /> }] },
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
