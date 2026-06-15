import { useTranslations } from "next-intl";
import { Container } from "../ui/Container";

type Step = { num: string; title: string; desc: string };

export function HowItWorks() {
  const t = useTranslations("how");
  const steps = t.raw("steps") as Step[];

  return (
    <section id="how" className="scroll-mt-20 bg-bg py-28">
      <Container>
        <div className="mx-auto flex max-w-2xl flex-col items-center text-center">
          <span className="text-[13px] font-semibold tracking-wider text-accent-dark">
            {t("eyebrow")}
          </span>
          <h2 className="mt-4 text-3xl font-bold leading-tight tracking-tight text-graphite-800 md:text-[40px]">
            {t("title")}
          </h2>
        </div>

        <div className="mt-16 grid gap-12 sm:grid-cols-2 lg:grid-cols-4">
          {steps.map((step, i) => (
            <div key={i} className="flex flex-col gap-4">
              <div className="flex items-center gap-3">
                <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-graphite-900 text-base font-bold text-accent-light">
                  {step.num}
                </span>
                {i < steps.length - 1 && (
                  <span className="hidden h-0.5 flex-1 bg-line lg:block" />
                )}
              </div>
              <div className="pr-6">
                <h3 className="text-lg font-semibold text-graphite-800">
                  {step.title}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-muted">
                  {step.desc}
                </p>
              </div>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
