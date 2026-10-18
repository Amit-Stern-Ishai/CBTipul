import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "../data/api";
import { Link } from "react-router-dom";
import { useAuth } from "../auth/Auth";
import nav from "../site-navigation.json";
import "../../site/chrome.css";

function current(href: string, path: string) {
  return (
    href === path ||
    (href === "/privacy/" && path === "/app/legal/privacy") ||
    (href === "/terms/" && path === "/app/legal/terms")
  );
}
export function SiteHeader({
  path = window.location.pathname,
  workspace = false,
}: {
  path?: string;
  workspace?: boolean;
}) {
  const { session, ready, logout } = useAuth();
  const profile = useQuery({
    queryKey: [session?.user.id, "profile"],
    queryFn: api.profile,
    enabled: ready && !!session && !session.user.is_anonymous,
    staleTime: 30_000,
    retry: 1,
  });
  const metadata = session?.user.user_metadata;
  const displayName = [profile.data?.display_name, metadata?.full_name, metadata?.name, session?.user.email]
    .find((value): value is string => typeof value === "string" && !!value.trim())?.trim();
  const [busy, setBusy] = useState(false),
    [error, setError] = useState(false);
  const signOut = async () => {
    setBusy(true);
    setError(false);
    try {
      await logout();
    } catch {
      setError(true);
    } finally {
      setBusy(false);
    }
  };
  const links = workspace
    ? [["/", nav.home]]
    : nav.links.filter(([href]) => ["/", "/support/"].includes(href));
  return (
    <>
      <a className="cb-skip skip-link" href="#content">
        {nav.skip}
      </a>
      <header className="cb-header site-header">
        <div className="cb-header-inner">
          <a
            className="cb-brand site-brand"
            href="/"
            aria-label="CBTipul — בית"
          >
            <img src="/site-assets/brand.png" alt="" width="40" height="40" />
            <span>CBTipul</span>
          </a>
          <nav className="cb-nav site-nav" aria-label={nav.navigation}>
            {links.map(([href, label]) => (
              <a
                key={href}
                href={href}
                aria-current={current(href, path) ? "page" : undefined}
              >
                {label}
              </a>
            ))}
            <div className="cb-auth">
              {ready && session && displayName && (
                <bdi className="cb-account-name" dir="auto">{displayName}</bdi>
              )}
              {workspace ? (
                <Link
                  className="therapist-link"
                  to="/"
                  aria-current={path === "/app/" ? "page" : undefined}
                >
                  {ready && session ? nav.workspace : nav.login}
                </Link>
              ) : (
                <a className="therapist-link" href="/app/">
                  {ready && session ? nav.workspace : nav.login}
                </a>
              )}
              {ready && session && (
                <button
                  type="button"
                  className="cb-logout"
                  disabled={busy}
                  aria-busy={busy}
                  onClick={() => void signOut()}
                >
                  {nav.logout}
                </button>
              )}
            </div>
            {error && (
              <p className="cb-auth-error" role="alert">
                {nav.logoutError}
              </p>
            )}
          </nav>
        </div>
      </header>
    </>
  );
}
export function SiteFooter({
  path = window.location.pathname,
}: {
  path?: string;
}) {
  return (
    <footer className="cb-footer site-footer">
      <div className="cb-footer-inner">
        <span>© 2026 CBTipul</span>
        <nav className="cb-footer-links footer-links" aria-label={nav.footer}>
          {nav.links
            .filter(([href]) => href !== "/")
            .map(([href, label]) => (
              <a
                key={href}
                href={href}
                aria-current={current(href, path) ? "page" : undefined}
              >
                {label}
              </a>
            ))}
        </nav>
      </div>
    </footer>
  );
}
