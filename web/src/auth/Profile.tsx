import { he } from "../he";
import { useState, type FormEvent, type ReactNode } from "react";
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "./Auth";
import { api } from "../data/api";
import { useAction, useWrite } from "../ui/hooks";
import { Loading, ErrorBox } from "../ui/shared";
export function ProfileGate({ children }: { children: ReactNode }) {
  const { session, logout } = useAuth();
  const write = useWrite();
  const profile = useQuery({
    queryKey: [session!.user.id, "profile"],
    queryFn: api.profile,
  });
  const [name, setName] = useState("");
  const save = useAction(() => api.saveProfile(name));
  async function submit(e: FormEvent) {
    e.preventDefault();
    if (save.isPending) return;
    try {
      await save.mutateAsync();
    } catch {
      /* inline error */
    }
  }
  if (profile.isPending) return <Loading />;
  if (profile.isError && !profile.data)
    return (
      <main className="gate">
        <ErrorBox error={profile.error} retry={() => void profile.refetch()} />
        <button onClick={() => void logout()}>{he.Profile001}</button>
      </main>
    );
  if (profile.data?.display_name?.trim() || !write) return children;
  return (
    <main className="gate">
      <h1>{he.Profile002}</h1>
      <p>{he.Profile003}</p>
      <form onSubmit={submit}>
        <label>
          {he.Profile004}
          <input
            required
            autoComplete="name"
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </label>
        {save.isError && <ErrorBox error={save.error} />}
        <button disabled={!name.trim() || save.isPending}>
          {he.Profile005}
        </button>
      </form>
    </main>
  );
}
