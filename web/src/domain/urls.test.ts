import { expect, it, vi } from "vitest";
import { appAsset, appRedirect } from "./urls";
it("keeps assets and auth callbacks under the same /app/ base", () => {
  vi.stubEnv("BASE_URL", "/app/");
  vi.stubGlobal("window", { location: { origin: "https://cbtipul.com" } });
  expect(appAsset("brand.png")).toBe("/app/brand.png");
  expect(appRedirect("/auth/callback")).toBe("https://cbtipul.com/app/auth/callback");
  expect(appRedirect("/auth/reset")).toBe("https://cbtipul.com/app/auth/reset");
  vi.unstubAllGlobals();
  vi.unstubAllEnvs();
});
