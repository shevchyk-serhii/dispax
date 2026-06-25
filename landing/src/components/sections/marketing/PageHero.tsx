import { ReactNode } from "react";
import { Container } from "../../ui/Container";
import { Link } from "@/i18n/navigation";
import { Icons } from "../../ui/icons";

/**
 * Dark gradient hero band for marketing sub-pages (mirrors the home Hero's
 * graphite gradient and neon streaks, without the home-specific dashboard).
 */
export function PageHero({
  eyebrow,
  title,
  subtitle,
  ctaPrimary,
  ctaSecondary,
  visual,
}: {
  eyebrow: string;
  title: string;
  subtitle: string;
  ctaPrimary?: { label: string; href: string };
  ctaSecondary?: { label: string; href: string };
  visual?: ReactNode;
}) {
  return (
    <section className="relative overflow-hidden bg-gradient-to-b from-graphite-700 via-graphite-800 to-graphite-900">
      <div className="pointer-events-none absolute inset-0" aria-hidden>
        <div className="absolute left-[-100px] top-[120px] h-1 w-[1100px] rotate-[8deg] bg-accent opacity-40 blur-[50px]" />
        <div className="absolute left-[400px] top-[320px] h-[5px] w-[1200px] -rotate-6 bg-accent-light opacity-30 blur-[55px]" />
      </div>

      <Container className="relative grid items-center gap-12 py-20 md:py-24 lg:grid-cols-2 lg:gap-16">
        <div>
          <span className="flex w-fit items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3.5 py-1.5 text-[13px] font-medium text-faint">
            <span className="h-[7px] w-[7px] rounded-full bg-accent" />
            {eyebrow}
          </span>
          <h1 className="mt-6 max-w-2xl text-4xl font-bold leading-[1.08] tracking-tight text-white sm:text-5xl">
            {title}
          </h1>
          <p className="mt-5 max-w-xl text-lg leading-relaxed text-faint">
            {subtitle}
          </p>
          {(ctaPrimary || ctaSecondary) && (
            <div className="mt-9 flex flex-col gap-4 sm:flex-row">
              {ctaPrimary && (
                <Link
                  href={ctaPrimary.href}
                  className="inline-flex items-center justify-center gap-2 rounded-md bg-accent px-6 py-3.5 text-[15px] font-semibold text-white transition-colors hover:bg-accent-dark"
                >
                  {ctaPrimary.label}
                  <Icons.arrowRight className="h-4 w-4" />
                </Link>
              )}
              {ctaSecondary && (
                <Link
                  href={ctaSecondary.href}
                  className="inline-flex items-center justify-center rounded-md border border-graphite-600 px-6 py-3.5 text-[15px] font-semibold text-white transition-colors hover:bg-white/5"
                >
                  {ctaSecondary.label}
                </Link>
              )}
            </div>
          )}
        </div>

        {visual && <div className="lg:pl-6">{visual}</div>}
      </Container>
    </section>
  );
}
