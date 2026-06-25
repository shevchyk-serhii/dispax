import { ReactNode } from "react";
import { useTranslations } from "next-intl";
import { Container } from "../ui/Container";
import { Logo } from "../ui/Logo";
import { Footer } from "./Footer";
import { Link } from "@/i18n/navigation";

/** A single titled paragraph block. `text` may contain newlines, rendered as line breaks. */
function Block({ label, text }: { label?: string; text: string }) {
  return (
    <div className="mt-8 first:mt-0">
      {label && (
        <h2 className="text-[15px] font-semibold tracking-wide text-ink">
          {label}
        </h2>
      )}
      <p className="mt-2 whitespace-pre-line text-[15px] leading-relaxed text-muted">
        {text}
      </p>
    </div>
  );
}

/** Shared chrome (header bar + back link + footer) for the legal pages. */
export function LegalPage({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  const t = useTranslations("legal");

  return (
    <div className="flex min-h-screen flex-col bg-bg">
      <header className="border-b border-line bg-surface">
        <Container>
          <div className="flex items-center justify-between py-6">
            <Link href="/" aria-label="Dispax">
              <Logo />
            </Link>
            <Link
              href="/"
              className="text-sm font-medium text-muted transition-colors hover:text-ink"
            >
              {t("back")}
            </Link>
          </div>
        </Container>
      </header>

      <main className="flex-1 py-16 md:py-24">
        <Container>
          <article className="mx-auto max-w-2xl">
            <h1 className="text-3xl font-bold tracking-tight text-ink md:text-4xl">
              {title}
            </h1>
            <div className="mt-10">{children}</div>
          </article>
        </Container>
      </main>

      <Footer />
    </div>
  );
}

export { Block as LegalBlock };
