import { rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { composeSite, webRoot } from "./compose-site.mjs";
await rm(path.join(webRoot, "dist"), { recursive: true, force: true });
for (const [name, args] of [["tsc", ["-b"]], ["vite", ["build"]]]) {
  const result = spawnSync(process.execPath, [path.join(webRoot, "node_modules", name === "tsc" ? "typescript/bin/tsc" : "vite/bin/vite.js"), ...args], { cwd: webRoot, stdio: "inherit" });
  if (result.status !== 0) process.exit(result.status ?? 1);
}
await composeSite();
console.log("Combined public site and /app/ workspace prepared in dist/");
