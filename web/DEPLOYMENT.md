# Combined CBTipul deployment — prepared, not published

Public website: `https://cbtipul.com/`. Therapist workspace: `https://cbtipul.com/app/`.
No deployment, Git push, custom-domain change, provider-setting change or backend change is authorized/performed by this preparation.

## Current configuration inspected on 14 October 2026

Read-only Cloudflare dashboard inspection confirmed:

| Item | Current value |
|---|---|
| Public Pages project | `cbtipul` — no Git connection / manually uploaded |
| Public custom domain | `cbtipul.com` — Active, SSL enabled |
| Apex DNS | Proxied CNAME `cbtipul.com` → `cbtipul.pages.dev`, TTL Auto |
| Existing public production deployment | `901a9ec3-c199-4614-b927-f94cd983ea6a` (`https://901a9ec3.cbtipul.pages.dev`) |
| Git-backed Pages project | `cbtipul-therapist-web` |
| Repository | `Amit-Stern-Ishai/CBTipul` |
| Build root / command / output | `web` / `npm ci && npm run build` / `dist` |
| Branch | `main`; automatic deployments enabled; watch paths `*` |
| Existing Git production commit | `a004863` |
| Build system | Version 3; build cache disabled; Node 24 |
| Existing Git project's domains | `cbtipul-therapist-web.pages.dev` (no apex attached) |
| Zone Worker routes | No routes configured |
| www | No www DNS record; dashboard reports it is not reachable |

Cloudflare cannot convert a Direct Upload Pages project to Git integration. Keep `cbtipul` available for rollback and move the apex to the **existing** Git-backed project after approval. See [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/).

There is no `.github/workflows` directory in the repository. The existing GitHub build workflow is Cloudflare Pages' GitHub integration. Its build command and output directory remain unchanged; the command now produces the complete combined artifact.

## Build, source and configuration

From repository root:

```sh
cd web
npm ci
npm run typecheck
npm run lint
npm run test
npm run test:site
npm run build
npm run test:browser
```

Build command in Cloudflare: `npm ci && npm run build`. Output directory relative to the build root: `dist`. Repository-relative output: `web/dist`.

- `site/source/`: original ZIP source, unchanged, including legal HTML and verification files.
- `site/source-manifest.json`: original SHA-256 checksums.
- `site/theme.css`: mobile/workspace branding for public pages.
- `scripts/compose-site.mjs`: shared public shell, download links, HTTP policies, preserved invitation script, byte-identical app-link verification files.
- `scripts/build.mjs`: typecheck/build workspace into `dist/app`, then compose public files into `dist`.
- `wrangler.jsonc`: existing Pages configuration (`name: cbtipul-therapist-web`, `pages_build_output_dir: ./dist`, compatibility date `2026-10-11`).
- `scripts/preview.mjs`: **local-only** `wrangler pages dev dist`; no deployment commands.

No Worker or Pages Function is needed. Do not create zone Worker routes, a `_worker.js`, or backend bindings for this site. `_redirects` and `_headers` are generated once at the artifact root, not inside `/app/`.

Required build variable names: `NODE_VERSION` (`24`), `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`. The two Vite values are public browser configuration. No service-role key, Google/Apple secret or OpenAI key belongs in the build. Wrangler does not require credentials for the local preview. Local preview disables usage metrics with `WRANGLER_SEND_METRICS=false`.

The repository already contains production browser configuration. Values are intentionally not copied into this handoff. Configure approved values in Cloudflare's Production environment. Preview environments should use an approved synthetic environment, never accidentally inherit production data access.

## Routing and preservation

Public routes remain real HTML at `/`, `/invite/`, `/privacy/`, `/terms/`, `/support/`, `/privacy-choices/`, `/delete-account/`, and their existing index files. `/style.css` remains available. Original support mail links and encoded account/data-deletion email subjects remain unchanged. There is no standalone password-reset page in the ZIP; the existing browser reset screen remains at `/app/auth/reset`.

Vite's base and React Router's basename are `/app/`. Logos/provider assets and generated CSS/JS are served below `/app/`. Browser OAuth and recovery `redirectTo` values include this prefix.

Only actual workspace routes are internally rewritten to the canonical `/app/` directory (without changing the requested URL): `/app/login`, `/app/auth/callback`, `/app/auth/reset`, `/app/legal/privacy`, `/app/legal/terms`. `/app/` is served directly from `app/index.html`; `/app` redirects to `/app/`. There is no catch-all `/app/*` or site-wide SPA rewrite. Future client routes must be added explicitly to the build's route list.

Top-level `404.html` prevents Pages' implicit site-wide SPA fallback. Unknown public pages and missing `/app/assets/*`, logos and verification files return 404. See [Serving Pages](https://developers.cloudflare.com/pages/configuration/serving-pages/).

`/invite/*` internally serves a separate `invite-landing.html` copy of the unchanged invitation content/script. The internal rewrite targets its extensionless alias `/invite-landing`, avoiding the original rule's canonical-path loop (`/invite/*` → `/invite/index.html`). Tokens are not placed in page content or browser storage. iOS, Android and iPad-on-Mac UA detection and both store destinations are retained. The `.well-known` files remain byte-identical and explicitly receive `application/json` with no redirects.

Legacy browser endpoints `/login`, `/auth/callback`, `/auth/reset`, `/legal/privacy` and `/legal/terms` redirect to their `/app/` equivalents. Query parameters survive server redirects; URL fragments remain browser-side. Mobile `cbtipul://` URLs are untouched.

Public CSP allows only the original inline script hashes and same-origin assets; public pages make no backend requests. Workspace CSP preserves the existing Supabase transport boundary. Workspace responses remain `no-store`; no clinical storage, logs or analytics were added.

## Authentication configuration required before release

Read-only Supabase inspection confirmed Site URL `http://localhost:3000` and only these two redirect allowlist entries:

- `cbtipul://auth-callback`
- `cbtipul://password-reset`

Keep both mobile entries. Add these exact browser URLs after separately approving provider/backend configuration work:

| Purpose | URL |
|---|---|
| Production Google/Apple PKCE | `https://cbtipul.com/app/auth/callback` |
| Production password recovery | `https://cbtipul.com/app/auth/reset` |
| Stable Pages staging PKCE | `https://cbtipul-therapist-web.pages.dev/app/auth/callback` |
| Stable Pages staging recovery | `https://cbtipul-therapist-web.pages.dev/app/auth/reset` |

For previously issued web email links/bookmarks, also retain/allow the corresponding legacy `/auth/callback` and `/auth/reset` URLs on `https://cbtipul.com` and `https://cbtipul-therapist-web.pages.dev`; the combined build redirects these to `/app/`. Do not allow wildcard preview hosts. Preview live auth should use a deliberately approved exact hostname and separate synthetic accounts.

Mocked local checks need no provider settings. If separately approving live local integration, allow `http://127.0.0.1:4173/app/auth/callback` and `http://127.0.0.1:4173/app/auth/reset` for this preview command.

Audit email templates and applications that rely on the fallback Site URL before changing it. The appropriate browser default for this deployment is `https://cbtipul.com/app/`, but do not blindly replace the current Site URL as part of domain routing. Explicit `redirectTo` values are already implemented. Templates should preserve the authorized redirect destination rather than hard-code the old root. See [Supabase redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls).

Provider → Supabase return URL stays exactly:

`https://cckklnxteyumsgiptfck.supabase.co/auth/v1/callback`

- **Google:** preserve the existing web OAuth client and all native iOS/Android clients. Its redirect URI must remain the Supabase URL above. Add/confirm authorized JavaScript origin `https://cbtipul.com` where the client uses that setting; origins have no `/app/` path. Preserve `https://cbtipul-therapist-web.pages.dev` for staging. Do not enter the app callback as Google's provider callback.
- **Apple:** preserve native identifier `com.CBTipul.app` and the existing browser Services ID (repository preparation identifies `com.CBTipul.app.web`; verify in the provider console). The registered return URL remains the Supabase URL above and its registered return domain remains `cckklnxteyumsgiptfck.supabase.co`. Moving the final frontend route to `/app/` does not itself require a different Apple return URL. Confirm any existing `cbtipul.com` website-domain registration remains valid. Provider-console settings/secret expiry were not inspected or changed. See [Supabase Apple sign-in](https://supabase.com/docs/guides/auth/social-login/auth-apple).
- Confirm existing Edge Function CORS permits browser origin `https://cbtipul.com`; the path `/app/` does not change an origin. Do not change CORS, functions, SQL, RLS or RPCs in this client task. Native callbacks, mobile entitlements and association files stay unchanged.

## Exact release / domain-switch procedure (future, requires approval)

1. Record/export the current zone DNS and custom-domain bindings. Save the old public deployment ID above and the original ZIP. Keep project `cbtipul` and its production deployment intact; do not delete them. Record existing redirect/cache rules, which were not audited in this task. Apex is currently a proxied Auto-TTL CNAME to `cbtipul.pages.dev`; eight other DNS records serve mail/auth mail and must be preserved.
2. Review this local implementation. **Do not push to `main` until publishing is authorized:** automatic deployments are currently enabled. After approval, merge/push the reviewed code into the Git-backed project's production branch. Existing build settings are already correct. Inspect the resulting combined deployment at its Pages URL before touching the apex. A preview deployment is also a publication and requires separate authorization.
3. Complete the approved auth configuration above. Use synthetic test accounts to verify email recovery, Google/Apple PKCE, cancellation, reload, logout and mobile callbacks. Confirm old `/auth/*` URLs preserve query/hash parameters and app-link files match the expected live bytes. Current tests are mocked, not proof of live auth.
4. In **Workers & Pages → cbtipul → Custom domains**, remove only the `cbtipul.com` association. Do not delete the Pages project, deployment, zone, mail records or native verification files. This is a coordinated cutover; plan for a brief interval while the domain is reassociated.
5. In **Workers & Pages → cbtipul-therapist-web → Custom domains → Set up a custom domain**, enter **`cbtipul.com`**. Follow the dashboard's DNS confirmation. If the old CNAME remains, replace only the apex web CNAME with **`cbtipul-therapist-web.pages.dev`**, maintaining **Proxied / TTL Auto**. Do not just edit DNS without attaching the Pages custom domain: that can produce a 522. See [Pages custom domains](https://developers.cloudflare.com/pages/configuration/custom-domains/).
6. Wait for the target custom domain to show **Active / SSL enabled**. Keep nameservers and all MX/TXT/auth-mail records unchanged. No Worker route is needed; none is currently configured. This plan changes the apex only; `www` is not currently configured.
7. Verify over HTTPS: all seven public pages; `/app/` entry/direct route/refresh; account-deletion mail subjects; invitation URLs on uninstalled and installed iOS/Android devices; exact store links; missing assets return 404; both verification files return direct 200 JSON; all auth round trips; no CSP/CORS regressions. Purge only relevant stale web cache if needed; do not evict unrelated infrastructure. Check real device association caches and store signing fingerprints.
8. Record the successful combined deployment ID and retain the old project as rollback until the observation period is complete. Do not remove legacy callback allowlist entries while old recovery emails may still be outstanding.

## Rollback

If cutover fails, remove `cbtipul.com` from the Git-backed project's Custom domains, then re-add it to **cbtipul → Custom domains**. Restore the apex CNAME to **`cbtipul.pages.dev`**, **Proxied / TTL Auto**, and wait for Active / SSL enabled. Keep the saved `901a9ec3` static deployment as production (use its Pages rollback action if it changed). Recheck public pages, invitation paths and both app-link files. Leave all mail records, mobile callbacks and backend/provider settings intact.

If the Git project's own build regresses before cutover, its previous `a004863` production deployment is a separate rollback option; the public apex is still on `cbtipul` at that stage. After a successful combined cutover, choose a previous **combined** deployment for normal Pages rollback rather than an old workspace-only artifact. A code revert alone does not restore a domain attachment.

## Validation and remaining live checks

The supplied source articles/scripts and both association files are verified against their byte/hash baseline. Browser checks use Chrome and Cloudflare's local Pages runtime, exercising the emitted `_redirects`, `_headers`, real 404 behavior, generated assets and responsive pages. Supabase/provider requests are intercepted with synthetic fixtures; these are not live service checks.

Before release, validate dashboard/build environment parity, production edge routing/headers/TLS, provider configuration and real auth, CORS, original app-link/store signing fingerprints and installed-device invitation opening. No domains or provider settings have been modified, and no artifact has been uploaded.
