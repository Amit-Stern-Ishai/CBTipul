# Cloudflare deployment preparation — not deployed

## Hosting choice

Use a **new Cloudflare Pages project** for this static SPA. It is the simplest fit for Vite's `dist/` output and does not need a Worker, server, or routing changes to the existing website.

Prepared `wrangler.jsonc` describes the Pages output but does not deploy. No deployment command is included in package scripts. The Wrangler CLI is not needed to build or review locally.

| Setting | Value |
|---|---|
| New Pages project | `cbtipul-therapist-web` (confirm availability in the target account) |
| Repository root directory | `web` |
| Build command | `npm ci && npm run build` |
| Build output | `dist` |
| Node version | `24` |
| Intended custom domain | `app.cbtipul.com` |
| Public build variables | `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` |

`public/_redirects` explicitly rewrites SPA paths to `/index.html` with 200. Routes such as `/patients/<id>/questionnaires/<id>` and `/auth/callback` must survive direct navigation/refresh. Do not add a top-level `404.html` that overrides SPA handling.

`public/_headers` sets no-store responses, no-referrer, framing protection, content-type protection and a CSP that permits only this origin and Supabase transport. No analytics is included. If the project uses a **custom Supabase domain**, review `connect-src` and authorized image hosts before deployment. Keep source maps off for the public build. Browser-storage auth state is not protected by response cache headers; use shared-computer precautions and logout.

## Exact callback URLs

Add these to the Supabase **redirect allowlist** after configuration is authorized:

- `https://app.cbtipul.com/auth/callback` — Google/Apple browser OAuth, PKCE.
- `https://app.cbtipul.com/auth/reset` — email password recovery, PKCE.
- For explicitly authorized local integration: `http://localhost:5173/auth/callback` and `http://localhost:5173/auth/reset`; if using the documented bound address, also `http://127.0.0.1:5173/auth/callback` and `http://127.0.0.1:5173/auth/reset`.

The app computes `redirectTo` from its current origin. Do not allow arbitrary production preview domains or broad wildcards. Test fixtures require no allowlist changes.

Provider → Supabase callback for the existing project remains:

`https://cckklnxteyumsgiptfck.supabase.co/auth/v1/callback`

- Google: use the existing Web OAuth client. Confirm its authorized origin includes `https://app.cbtipul.com` and its redirect URI remains the Supabase callback above. Preserve all iOS/Android clients. No client secret belongs in this app.
- Apple: use existing browser Services ID `com.CBTipul.app.web`, its existing server-side secret in Supabase and registered Supabase return URL. Confirm Apple/Supabase accept the web round trip. Do not replace the native `com.CBTipul.app` client ID. Never send a Supabase PKCE callback code to native `register-apple-token`.
- Do **not** replace the Supabase Site URL blindly: other apps and emails may depend on it. Explicit allowed redirects are used here. Preserve current `cbtipul://auth-callback`, password-reset callbacks, mobile Universal/App Links and invitation URLs.

## Review / release checklist

Before any public deployment:

1. Review this implementation, contract discrepancies and approved web-specific legal text in `CONTRACTS.md`.
2. Obtain explicit authorization to create/deploy the separate Pages project. Preview deployments are public too unless protected; do not automatically upload a preview.
3. Confirm public Supabase values and configure the exact authorized callback URLs above. Verify function CORS permits the new origin and RLS rejects unauthorized/patient users. No backend/provider changes were made by this task.
4. Use synthetic test accounts/records in an authorized environment to validate email, Google/Apple PKCE, cancellation, recovery, reload, sign-out/account switch, and same-account patient access. Verify persistent sessions and provider Hide My Email behavior; do not merge accounts in the client.
5. Validate representative live contract shapes under authorization: old/no-date results, all diary schemas, ongoing activation/cancellation, notifications, messages, AI anonymization/quotas, and empty note saving. Check server row caps/pagination with a large synthetic dataset.
6. Verify identity labels never appear in outgoing requests and that logout clears labels and clinical state, including another tab. Verify browser back after logout cannot restore a clinical view.
7. After deployment is separately approved, attach **only** `app.cbtipul.com` to the new Pages project. Do not change apex/www records, existing Worker routes or the project serving `cbtipul.com`.
8. Preserve and recheck `cbtipul.com` homepage, `/privacy/`, `/terms/`, `/support/`, `/privacy-choices/`, `/delete-account/`, existing invitation landing paths, `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json`. Do not copy SPA rewrites to the main site's deployment.
9. Test direct refresh of every new SPA route, CSP headers and OAuth callbacks over HTTPS. No PHI in CDN/browser disk caches, telemetry or error reporting. No real clinical edits without permission.
10. Rollback changes **only** in the new Pages project/custom-domain attachment; leave mobile and main-site hosting intact.

## Official references consulted

- [Cloudflare Pages React deployment](https://developers.cloudflare.com/pages/framework-guides/deploy-a-react-site/)
- [Cloudflare Pages serving pages / SPA behavior](https://developers.cloudflare.com/pages/configuration/serving-pages/)
- [Vite static deployment](https://vite.dev/guide/static-deploy.html)
- [React Router modes](https://reactrouter.com/start/modes)
- [TanStack Query React](https://tanstack.com/query/latest/docs/framework/react/overview)
- [Supabase Google browser OAuth and PKCE](https://supabase.com/docs/guides/auth/social-login/auth-google)

Installed package versions are locked in `package-lock.json`. Google/Apple logos are copied from the existing official mobile sign-in assets; the app logo is the existing CBTipul asset.
