import { useTranslations } from "next-intl";
import { Container } from "../ui/Container";
import { NavBar } from "../ui/NavBar";
import { DashboardMock } from "./DashboardMock";

export function Hero() {
  const t = useTranslations("hero");

  return (
    <section
      id="top"
      className="relative overflow-hidden bg-gradient-to-b from-graphite-700 via-graphite-800 to-graphite-900"
    >
      {/* neon streaks */}
      <div className="pointer-events-none absolute inset-0" aria-hidden>
        <div className="absolute left-[-100px] top-[230px] h-1 w-[1100px] rotate-[8deg] bg-accent opacity-50 blur-[50px]" />
        <div className="absolute left-[500px] top-[430px] h-[5px] w-[1200px] -rotate-6 bg-accent-light opacity-35 blur-[55px]" />
        <div className="absolute left-[200px] top-[620px] h-[3px] w-[900px] rotate-[10deg] bg-accent opacity-40 blur-[45px]" />
      </div>

      <div className="relative">
        <NavBar />

        <Container className="flex flex-col items-center pb-24 pt-12 md:pt-20">
          <span className="flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-3.5 py-1.5 text-[13px] font-medium text-faint">
            <span className="h-[7px] w-[7px] rounded-full bg-accent" />
            {t("badge")}
          </span>

          <h1 className="mt-7 max-w-3xl text-center text-4xl font-bold leading-[1.05] tracking-tight text-white sm:text-5xl md:text-6xl">
            {t("title")}
          </h1>

          <p className="mt-6 max-w-xl text-center text-lg leading-relaxed text-faint">
            {t("subtitle")}
          </p>

          <div className="mt-10 flex flex-col items-center gap-4 sm:flex-row">
            <a
              href="#contact"
              className="rounded-md bg-accent px-6 py-3.5 text-[15px] font-semibold text-white transition-colors hover:bg-accent-dark"
            >
              {t("ctaPrimary")}
            </a>
            <a
              href="#how"
              className="rounded-md border border-graphite-600 px-6 py-3.5 text-[15px] font-semibold text-white transition-colors hover:bg-white/5"
            >
              {t("ctaSecondary")}
            </a>
          </div>

          <div className="mt-16 w-full max-w-5xl">
            <DashboardMock />
          </div>
        </Container>
      </div>
    </section>
  );
}
