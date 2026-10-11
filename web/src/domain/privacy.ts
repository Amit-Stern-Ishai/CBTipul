import { he } from "../he";
// Names are convenience labels, never part of clinical DTOs.
const prefix = (account: string) => `cbtipul.names.${account}.`;
export const names = {
  get: (storage: Storage, account: string, id: string | number) =>
    storage.getItem(prefix(account) + id)?.trim() || "",
  set: (
    storage: Storage,
    account: string,
    id: string | number,
    value: string,
  ) => {
    const key = prefix(account) + id;
    if (value.trim()) storage.setItem(key, value.trim());
    else storage.removeItem(key);
  },
  clear: (storage: Storage, account: string) => {
    Object.keys(storage)
      .filter((k) => k.startsWith(prefix(account)))
      .forEach((k) => storage.removeItem(k));
  },
  redact: (storage: Storage, account: string, text: string) => {
    const labels = Object.keys(storage)
      .filter((k) => k.startsWith(prefix(account)))
      .map((k) => storage.getItem(k) || "")
      .flatMap((name) => [
        name,
        ...name.split(/\s+/).filter((part) => part.length >= 2),
      ])
      .filter(Boolean)
      .sort((a, b) => b.length - a.length);
    return labels.reduce(
      (value, name) => value.split(name).join(he.privacy001),
      text,
    );
  },
};
export function therapistAllowed(
  user: { is_anonymous?: boolean } | null,
  context: { role: string } | null,
) {
  return !!user && user.is_anonymous === false && context?.role === "therapist";
}
