import { he } from "../he";
const prefix = (account: string) => `cbtipul.names.${account}.`;
const memory = new Map<string, Map<string, string>>();
export const names = {
 get: (_storage: Storage, account: string, id: string | number) => memory.get(account)?.get(String(id).toLowerCase()) ?? "",
 set: (_storage: Storage, account: string, id: string | number, value: string) => {
  if(!memory.has(account))memory.set(account,new Map());
  memory.get(account)!.set(String(id).toLowerCase(),value);
 },
 clear: (storage: Storage, account: string) => {
  memory.delete(account);
  Object.keys(storage).filter(k=>k.startsWith(prefix(account))).forEach(k=>storage.removeItem(k));
 },
 redact: (_storage: Storage, account: string, text: string) => {
  const labels=[...(memory.get(account)?.values() ?? [])].flatMap(n=>[n,...n.split(/\s+/).filter(p=>p.length>=2)]).filter(Boolean).sort((a,b)=>b.length-a.length);
  return labels.reduce((value,name)=>value.split(name).join(he.privacy001),text);
 },
};
export function therapistAllowed(
  user: { is_anonymous?: boolean } | null,
  context: { role: string } | null,
) {
  return !!user && user.is_anonymous === false && context?.role === "therapist";
}
