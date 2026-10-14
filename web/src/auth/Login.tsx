import { he } from "../he";
import { useState, type FormEvent } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { supabase, configured } from "../data/client";
import { ErrorBox } from "../ui/shared";
import { useAuth } from "./Auth";
export function Login() {
  const location = useLocation(),
    navigate = useNavigate(),
    { session } = useAuth();
  const reset = location.pathname === "/auth/reset";
  const [email, setEmail] = useState(""),
    [password, setPassword] = useState(""),
    [busy, setBusy] = useState(false),
    [error, setError] = useState<unknown>(null),
    [sent, setSent] = useState(false),
    [recover, setRecover] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      const r = reset
        ? await supabase.auth.updateUser({ password })
        : recover
          ? await supabase.auth.resetPasswordForEmail(email, {
              redirectTo: locationOrigin("/auth/reset"),
            })
          : await supabase.auth.signInWithPassword({ email, password });
      if (r.error) throw r.error;
      if (recover) setSent(true);
      else navigate("/", { replace: true });
    } catch (e) {
      setError(e);
    } finally {
      setBusy(false);
    }
  }
  async function oauth(provider: "google" | "apple") {
    if (busy || session) return;
    setBusy(true);
    setError(null);
    const r = await supabase.auth.signInWithOAuth({
      provider,
      options: { redirectTo: locationOrigin("/auth/callback") },
    });
    if (r.error) setError(r.error);
    setBusy(false);
  }
  return (
    <main className="auth-page">
      <section className="auth-story">
        <img src="/brand.png" alt="CBTipul" />
        <p className="eyebrow">{he.Login001}</p>
        <h1>
          {he.Login002}
          <br />
          {he.Login003}
        </h1>
        <p>{he.Login004}</p>
        <div className="story-lines">
          <span />
          <span />
          <span />
        </div>
      </section>
      <section className="auth-form">
        <h2>{reset ? he.Login005 : recover ? he.Login006 : he.Login007}</h2>
        <p>{he.Login008}</p>
        {!configured ? (
          <div className="notice">{he.Login009}</div>
        ) : (
          <>
            {!reset && !recover && (
              <div className="provider-buttons">
                <button
                  className="google"
                  disabled={busy || !!session}
                  onClick={() => void oauth("google")}
                >
                  <img src="/google.png" alt="" />
                  {he.Login010}
                </button>
                <button
                  className="apple"
                  disabled={busy || !!session}
                  onClick={() => void oauth("apple")}
                >
                  <img src="/apple.svg" alt="" />
                  {he.Login011}
                </button>
                <p className="small">{he.Login012}</p>
                <div className="divider">{he.Login013}</div>
              </div>
            )}
            {sent ? (
              <p role="status" className="notice">
                {he.Login014}
              </p>
            ) : (
              <form onSubmit={submit}>
                {!reset && (
                  <label>
                    {he.Login015}
                    <input
                      dir="ltr"
                      type="email"
                      autoComplete="email"
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                    />
                  </label>
                )}
                {(!recover || reset) && (
                  <label>
                    {he.Login016}
                    <input
                      type="password"
                      dir="ltr"
                      autoComplete={reset ? "new-password" : "current-password"}
                      minLength={reset ? 8 : undefined}
                      required
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                    />
                  </label>
                )}
                {!!error && <ErrorBox error={error} />}
                <button className="wide" disabled={busy || (reset && !session)}>
                  {busy
                    ? he.Login017
                    : reset
                      ? he.Login018
                      : recover
                        ? he.Login019
                        : he.Login020}
                </button>
                {reset && !session && <p className="notice">{he.Login021}</p>}
              </form>
            )}
            {!reset && (
              <button
                className="text-button"
                onClick={() => {
                  setRecover(!recover);
                  setSent(false);
                  setError(null);
                }}
              >
                {recover ? he.Login022 : he.Login023}
              </button>
            )}
          </>
        )}
        <footer>
          <Link to="/legal/terms">{he.Login024}</Link>
          <Link to="/legal/privacy">{he.Login025}</Link>
        </footer>
      </section>
    </main>
  );
}
function locationOrigin(path: string) {
  return window.location.origin + path;
}
