import { ReactNode } from "react";
import { NavBar } from "../ui/NavBar";
import { Footer } from "./Footer";

/**
 * Shell for the light marketing sub-pages: sticky light NavBar + content + Footer.
 * (The dark home Hero renders its own NavBar; the minimal LegalPage is separate.)
 */
export function MarketingPage({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen flex-col bg-bg">
      <NavBar variant="light" />
      <main className="flex-1">{children}</main>
      <Footer />
    </div>
  );
}
