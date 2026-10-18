// Public pages use the same auth client/storage and chrome, never clinical queries.
import React from "react";
import { createRoot } from "react-dom/client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { AuthProvider } from "./auth/Auth";
import { SiteHeader, SiteFooter } from "./ui/SiteChrome";
const header = document.getElementById("site-header-root");
const footer = document.getElementById("site-footer-root");
if (header)
  createRoot(header).render(
    <React.StrictMode>
      <QueryClientProvider client={new QueryClient()}>
        <AuthProvider>
          <SiteHeader />
        </AuthProvider>
      </QueryClientProvider>
    </React.StrictMode>,
  );
if (footer) createRoot(footer).render(<SiteFooter />);
