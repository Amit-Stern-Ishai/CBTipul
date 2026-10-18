import { readFile, writeFile, mkdir, cp, rm } from "node:fs/promises";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import path from "node:path";
export const webRoot = fileURLToPath(new URL("../", import.meta.url));
export const pages = ["", "invite", "privacy", "terms", "support", "privacy-choices", "delete-account"];
const navigation = JSON.parse(await readFile(path.join(webRoot,"src/site-navigation.json"),"utf8"));
const labels = navigation.links;
const stores = `<div class="store-actions" aria-label="הורדת האפליקציה"><a class="store-button" href="https://apps.apple.com/il/app/cbtipul/id6809343831?l=he" rel="noopener noreferrer"><img class="store-mark" src="/site-assets/store-apple.svg" alt="" width="28" height="32" /><span>הורדה מ-App Store</span></a><a class="store-button secondary" href="https://play.google.com/store/apps/details?id=com.CBTipul.app" rel="noopener noreferrer"><img class="store-mark" src="/site-assets/store-google-play.svg" alt="" width="28" height="32" /><span>הורדה מ-Google Play</span></a></div>`;
export const redirects = `/app /app/ 302
/app/login /app/ 200
/app/auth/callback /app/ 200
/app/auth/reset /app/ 200
/app/legal/privacy /app/ 200
/app/legal/terms /app/ 200
/login /app/login 302
/auth/callback /app/auth/callback 302
/auth/reset /app/auth/reset 302
/legal/privacy /app/legal/privacy 302
/legal/terms /app/legal/terms 302
/invite/* /invite-landing 200
`;
export async function composeSite(output = path.join(webRoot, "dist"), publicAssets) {
  if (!publicAssets) {
    const manifest = JSON.parse(await readFile(path.join(output,"app/.vite/manifest.json"),"utf8"));
    const entry = manifest["src/public-site.tsx"];
    const css = new Set();
    const visit = (chunk) => { for (const file of chunk.css ?? []) css.add(`/app/${file}`); for (const dep of chunk.imports ?? []) visit(manifest[dep]); };
    visit(entry); publicAssets = { script:`/app/${entry.file}`, styles:[...css] };
  }
  await mkdir(output, { recursive: true });
  const hashes = new Set();
  const theme = await readFile(path.join(webRoot, "site/theme.css"));
  const themeUrl = `/site-assets/theme-${createHash("sha256").update(theme).digest("hex").slice(0, 12)}.css`;
  await mkdir(path.join(output, "site-assets"), { recursive: true });
  await writeFile(path.join(output, themeUrl), theme);
  let fallbackHeader = "", fallbackFooter = "";
  for (const page of pages) {
    const url = page ? `/${page}/` : "/";
    let html = await readFile(path.join(webRoot, "site/source", page, "index.html"), "utf8");
    html = html.replace(/href="\/style\.css"/g, `href="${themeUrl}"`);
    // Source content and behavior remain authoritative; only the shared shell is replaced.
    html = html.replace(/<style>[\s\S]*?<\/style>/g, "");
    html = html.replace(/<nav>[\s\S]*?<\/nav>/g, "");
    const header = `<div id="site-header-root"><a class="cb-skip skip-link" href="#content">${navigation.skip}</a><header class="cb-header site-header"><div class="cb-header-inner"><a class="cb-brand site-brand" href="/" aria-label="CBTipul — בית"><img src="/site-assets/brand.png" alt="" width="40" height="40" /><span>CBTipul</span></a><nav class="cb-nav site-nav" aria-label="${navigation.navigation}">${labels.filter(([href])=>["/","/support/"].includes(href)).map(([href,label])=>`<a href="${href}"${href===url?' aria-current="page"':""}>${label}</a>`).join("")}<div class="cb-auth"><a class="therapist-link" href="/app/">${navigation.login}</a></div></nav></div></header></div>`;
    html = html.replace("</head>",`${publicAssets.styles.map(href=>`<link rel="stylesheet" href="${href}">`).join("")}<script type="module" src="${publicAssets.script}"></script></head>`);
    html = html.replace(/<body([^>]*)>/, `<body$1>${header}`);
    html = html.replace(/<main([^>]*)>/, `<main$1 id="content" tabindex="-1">`);
    html = html.replace(/<body([^>]*)>/, (_match, attrs) => `<body${attrs} data-page="${page || "home"}">`);
    html = html.replace(/<body([^>]*)>/, (_match, attrs) => attrs.includes('class=') ? `<body${attrs.replace(/class="([^"]*)"/, `class="$1 document-page ${page}-page"`)}>` : `<body${attrs} class="${page ? `document-page ${page}-page` : "home-page"}">`);
    if (!page) html = html.replace("</article>", `${stores}</article>`);
    html = html.replace(/<footer[^>]*>[\s\S]*?<\/footer>/g, "");
    const footer = `<div id="site-footer-root"><footer class="cb-footer site-footer"><div class="cb-footer-inner"><span>© 2026 CBTipul</span><nav class="cb-footer-links footer-links" aria-label="${navigation.footer}">${labels.filter(([href])=>href!=="/").map(([href,label])=>`<a href="${href}"${href===url?' aria-current="page"':""}>${label}</a>`).join("")}</nav></div></footer></div>`;
    if (!page) { fallbackHeader = header.replace(' aria-current="page"', ""); fallbackFooter = footer; }
    html = html.replace("</body>", `${footer}</body>`);
    for (const match of html.matchAll(/<script>([\s\S]*?)<\/script>/g)) hashes.add(`'sha256-${createHash("sha256").update(match[1]).digest("base64")}'`);
    const folder = path.join(output, page); await mkdir(folder, { recursive: true }); await writeFile(path.join(folder, "index.html"), html);
    if (page === "invite") await writeFile(path.join(output, "invite-landing.html"), html);
  }
  await cp(path.join(webRoot, "site/source/.well-known"), path.join(output, ".well-known"), { recursive: true });
  await cp(path.join(webRoot, "site/theme.css"), path.join(output, "style.css"));
  await mkdir(path.join(output, "site-assets"), { recursive: true });
  for (const name of ["store-apple.svg", "store-google-play.svg"]) await cp(path.join(webRoot, "site", name), path.join(output, "site-assets", name));
  await cp(path.join(webRoot, "public/brand.png"), path.join(output, "site-assets/brand.png"));
  await writeFile(path.join(output, "404.html"), `<!doctype html><html lang="he" dir="rtl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>העמוד לא נמצא — CBTipul</title><link rel="stylesheet" href="${themeUrl}">${publicAssets.styles.map(href=>`<link rel="stylesheet" href="${href}">`).join("")}<script type="module" src="${publicAssets.script}"></script></head><body>${fallbackHeader}<main id="content" tabindex="-1"><article class="card"><h1>העמוד לא נמצא</h1><p>אפשר לחזור לעמוד הבית או להיכנס למרחב למטפלים.</p><a href="/">בית</a> · <a href="/app/">כניסה למטפלים</a></article></main>${fallbackFooter}</body></html>`);
  await rm(path.join(output,"app/.vite"),{recursive:true,force:true});
  await writeFile(path.join(output, "_redirects"), redirects);
  const common = "  Referrer-Policy: no-referrer\n  X-Content-Type-Options: nosniff\n  X-Frame-Options: DENY\n  Permissions-Policy: camera=(), microphone=(), geolocation=()\n";
  const publicCsp = `default-src 'self'; script-src 'self' ${[...hashes].join(" ")}; style-src 'self'; img-src 'self'; connect-src 'self' https://*.supabase.co wss://*.supabase.co; frame-ancestors 'none'; base-uri 'self'; object-src 'none'; form-action 'self'`;
  const appCsp = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob: https://*.supabase.co; connect-src 'self' https://*.supabase.co wss://*.supabase.co; frame-ancestors 'none'; base-uri 'self'; object-src 'none'; form-action 'self'";
  let headers = "";
  for (const pattern of ["/", "/index.html", "/invite-landing", "/invite-landing.html", ...pages.filter(Boolean).map((p) => `/${p}/*`), "/404.html"]) headers += `${pattern}\n${common}  Content-Security-Policy: ${publicCsp}\n\n`;
  headers += `/app/*\n${common}  Cache-Control: no-store\n  Content-Security-Policy: ${appCsp}\n\n/.well-known/*\n  Content-Type: application/json\n  X-Content-Type-Options: nosniff\n  Cache-Control: public, max-age=3600\n`;
  await writeFile(path.join(output, "_headers"), headers);
}
