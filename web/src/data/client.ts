import { createClient } from "@supabase/supabase-js";
const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
export const configured =
  !!url &&
  !!key &&
  !url.includes("YOUR_PROJECT") &&
  !key.includes("YOUR_PUBLIC");
export const supabase = createClient(
  configured ? url : "https://unconfigured.invalid",
  configured ? key : "unconfigured-public-key",
  {
    auth: {
      flowType: "pkce",
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      storageKey: "cbtipul.web.auth",
    },
  },
);
