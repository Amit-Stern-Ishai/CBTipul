import { useRef } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "../auth/Auth";
import { api } from "../data/api";
export function usePatients() {
  const { session } = useAuth();
  return useQuery({
    queryKey: [session?.user.id, "patients"],
    queryFn: api.patients,
  });
}
export function useContextAccess(poll = false) {
  const { session } = useAuth();
  return useQuery({
    queryKey: [session?.user.id, "access"],
    queryFn: api.context,
    enabled: !!session && !session.user.is_anonymous,
    staleTime: 60_000,
    refetchInterval: poll ? 60_000 : false,
    refetchIntervalInBackground: false,
    retry: 1,
  });
}
export function useWrite() {
  const access = useContextAccess();
  return !access.isError && access.data?.entitlement?.access === "full";
}
export function useAction<T, V = void>(action: (v: V) => Promise<T>) {
  const client = useQueryClient();
  const running = useRef(false);
  return useMutation({
    mutationFn: async (value: V) => {
      if (running.current) throw new Error("operation_in_progress");
      running.current = true;
      try {
        return await action(value);
      } finally {
        running.current = false;
      }
    },
    onSuccess: () => client.invalidateQueries(),
  });
}
