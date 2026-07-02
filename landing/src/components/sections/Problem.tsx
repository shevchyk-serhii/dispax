import { useTranslations } from "next-intl";
import { Container } from "../ui/Container";
import { SectionHeader } from "../ui/SectionHeader";
import { Icons, IconName } from "../ui/icons";
import { Reveal } from "../ui/Reveal";

const icons: IconName[] = ["clock", "plane", "scatter", "bellOff"];

type Item = { title: string; desc: string };

export function Problem() {
  const t = useTranslations("problem");
  const items = t.raw("items") as Item[];

  return (
    <section className="bg-bg py-28">
      <Container>
        <Reveal>
          <SectionHeader
            eyebrow={t("eyebrow")}
            title={t("title")}
            subtitle={t("subtitle")}
          />
        </Reveal>
        <div className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {items.map((item, i) => {
            const Icon = Icons[icons[i]];
            return (
              <Reveal
                key={i}
                delay={(Math.min(i, 3) as 0 | 1 | 2 | 3)}
                className="rounded-xl border border-line bg-surface p-7 transition-all hover:-translate-y-1 hover:border-accent/30 hover:shadow-glow-sm"
              >
                <span className="flex h-11 w-11 items-center justify-center rounded-[10px] bg-accent/10 text-accent-dark">
                  <Icon className="h-[22px] w-[22px]" />
                </span>
                <h3 className="mt-3.5 text-[17px] font-semibold leading-snug text-graphite-800">
                  {item.title}
                </h3>
                <p className="mt-2 text-sm leading-relaxed text-muted">
                  {item.desc}
                </p>
              </Reveal>
            );
          })}
        </div>
      </Container>
    </section>
  );
}
