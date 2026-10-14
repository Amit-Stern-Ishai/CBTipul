Public website source

source/ is the original CBTipul-web-with-invite-stores-v4.zip content, byte-for-byte.
source-manifest.json records its SHA-256 hashes. Keep legal and invitation behavior changes explicit and reviewed.
theme.css is the public branding layer. scripts/compose-site.mjs adds the shared accessible header/footer, therapist link, landing download actions and scoped hosting rules at build time.
There is no static password-reset page in the supplied ZIP. The existing workspace reset UI is preserved at /app/auth/reset, with a compatibility redirect from /auth/reset.
All source pages are emitted as real HTML. No JavaScript framework or analytics is added to public pages.
