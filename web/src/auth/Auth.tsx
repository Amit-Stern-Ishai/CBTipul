import { he } from "../he";
import { unsaved } from "../domain/dirty";
import {
  createContext,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import type { Session } from "@supabase/supabase-js";
import { useQueryClient } from "@tanstack/react-query";
import { supabase, configured } from "../data/client";
import { names } from "../domain/privacy";
import { setApiIdentity } from "../data/api";
interface AuthValue {
  session: Session | null;
  ready: boolean;
  logout: () => Promise<void>;
}
const AuthContext = createContext<AuthValue>({
  session: null,
  ready: false,
  logout: async () => {},
});
export const useAuth = () => useContext(AuthContext);
export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null),
    [ready, setReady] = useState(!configured);
  const account = useRef<string | null>(null),
    client = useQueryClient();
  useEffect(() => {
    if (!configured) return;
    let alive = true;
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, next) => {
      if (!alive) return;
      const nextId = next?.user.id ?? null;
      if (account.current !== nextId) {
        if (account.current) names.clear(localStorage, account.current);
        client.clear();
        account.current = nextId;
        setApiIdentity(nextId);
      }
      setSession(next);
      setReady(true);
    });
    return () => {
      alive = false;
      subscription.unsubscribe();
    };
  }, [client]);
  const logout = async () => {
    if (unsaved.active && !window.confirm(he.Auth001)) return;
    const id = account.current;
    setApiIdentity(null);
    client.clear();
    if (id) names.clear(localStorage, id);
    setSession(null);
    account.current = null;
    await supabase.auth.signOut({ scope: "local" });
  };
  return (
    <AuthContext.Provider value={{ session, ready, logout }}>
      {children}
    </AuthContext.Provider>
  );
}
