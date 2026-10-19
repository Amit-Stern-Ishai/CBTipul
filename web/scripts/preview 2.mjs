import { spawn } from "node:child_process";
import path from "node:path";
import { webRoot } from "./compose-site.mjs";
const args = process.argv.slice(2);
const runner = spawn(process.execPath, [path.join(webRoot, "node_modules/wrangler/bin/wrangler.js"), "pages", "dev", "dist", "--ip", "127.0.0.1", ...(args.includes("--port") ? [] : ["--port", "4173"]), ...args], { cwd: webRoot, stdio: "inherit", env: { ...process.env, WRANGLER_SEND_METRICS: "false" } });
for (const signal of ["SIGTERM", "SIGINT"]) process.on(signal, () => runner.kill(signal));
runner.on("exit", (code) => process.exit(code ?? 0));
