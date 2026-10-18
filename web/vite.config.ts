import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
export default defineConfig({
  base: "/app/",
  plugins: [react()],
  test: { include: ["src/**/*.test.ts"] },
  build: { sourcemap: false, outDir: "dist/app", manifest: true, rollupOptions: { input: { workspace: "index.html", "public-site": "src/public-site.tsx" } } },
});
