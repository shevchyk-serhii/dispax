import { useTranslations } from "next-intl";
import { Container } from "../ui/Container";
import { WaitlistForm } from "./WaitlistForm";

export function CtaWaitlist() {
  const t = useTranslations("cta");

  return (
    <section id="contact" className="scroll-mt-20 bg-surface py-28">
      <Container>
        <div className="relative mx-auto flex max-w-3xl flex-col items-center overflow-hidden rounded-3xl bg-gradient-to-br from-graphite-700 via-graphite-800 to-graphite-900 px-8 py-16 text-center md:px-[72px]">
          <div className="pointer-events-none absolute inset-0" aria-hidden>
            <div className="absolute left-[-50px] top-[130px] h-[5px] w-[980px] -rotate-9 bg-accent opacity-45 blur-[55px]" />
          </div>

          <div className="relative flex flex-col items-center">
            <h2 className="max-w-xl text-3xl font-bold leading-tight tracking-tight text-white md:text-[38px]">
              {t("title")}
            </h2>
            <p className="mt-5 max-w-md text-[17px] leading-relaxed text-faint">
              {t("subtitle")}
            </p>
            <WaitlistForm />
          </div>
        </div>
      </Container>
    </section>
  );
}
