export const appAsset = (name: string) => `${import.meta.env.BASE_URL}${name}`;
export const appRedirect = (path: string) => `${window.location.origin}${import.meta.env.BASE_URL}${path.replace(/^\//, "")}`;
