# Combined-site verification — 14 October 2026

- Strict typecheck and ESLint passed.
- 70 Vitest unit tests passed, including workspace privacy/save lifecycle/scoring and /app/ asset/auth URL generation.
- Node preservation check passed: original articles and invitation scripts are included unchanged; source hashes match the imported ZIP; both app-link verification files match byte-for-byte.
- 32 Playwright Chrome tests passed against Cloudflare's local Pages runtime (Wrangler 4.151.0), including all seven public pages at 1440px and 390px, navigation/keyboard focus/no overflow, original text and support/deletion links, direct /app/ entry and refresh, direct 200 callbacks/reset/legal routes without redirects, correct prefixed assets, genuine missing-file 404s, direct 200 JSON verification files, and desktop/iOS/Android/iPad invitation detection.
- Browser Supabase/provider traffic was intercepted with synthetic fixtures. Google/Apple redirect_to URLs were verified without real provider round trips.
- Public pages were visually inspected in batched desktop/phone contact sheets. Account-deletion semantic styling and the reset screen were checked in the confirmation pass.
- Main contrast ratios: navy body 14.12:1; secondary text 6.65:1; link/focus blue 7.16:1; white on navy button 10.92:1; navy on gold 7.80:1; destructive text 5.68:1.
- Combined production build passed with source maps off. Existing Vite bundle-size advisory remains nonblocking (approximately 691 kB main JS / 201 kB gzip).
- git diff --check passed; changes are confined to web/. The original mobile/backend code is unchanged.

The repository's previously stalled installed dependencies were left intact. Compilation/lint/build used a current-source copy with fresh lockfile-pinned dependencies in a local isolated validation directory. The existing public production .env was copied for final compilation without displaying its values; browser tests instead compiled with synthetic configuration. No service-role/provider/OpenAI secrets were added.

Read-only Cloudflare/Supabase dashboard inspection identified the current hosting, DNS/custom-domain binding, build settings, lack of Worker routes and missing browser auth allowlist. No deploy, remote push, domain/DNS change, backend/provider change, live sign-in, clinical write, account deletion, email transmission or real-device test occurred.

Before publication, complete the exact approved authentication and cutover steps in DEPLOYMENT.md, then verify production edge headers/TLS/404s, CORS, provider round trips and installed-device Universal/App Links on synthetic accounts. Local tests do not prove live provider configuration or device association caches.
