import { useTranslations } from "next-intl";
import { Container } from "../ui/Container";
import { SectionHeader } from "../ui/SectionHeader";
import { Icons, IconName } from "../ui/icons";
import { StatusBadge, FeatureStatus } from "../ui/StatusBadge";
import { Reveal } from "../ui/Reveal";

const primaryIcons: IconName[] = ["dashboard", "planeLand", "pin"];
const secondaryIcons: IconName[] = [
  "shield",
  "chart",
  "swap",
  "calendarCheck",
  "fileShield",
];

type Item = { title: string; desc: string; status?: FeatureStatus };

export function Features() {
  const t = useTranslations("features");
  const primary = t.raw("primary") as Item[];
  const secondary = t.raw("secondary") as Item[];

  return (
    <section id="features" className="scroll-mt-20 bg-surface py-28">
      <Container>
        <Reveal>
          <SectionHeader
            eyebrow={t("eyebrow")}
            title={t("title")}
            subtitle={t("subtitle")}
          />
        </Reveal>

        <div className="mt-14 grid gap-6 md:grid-cols-3">
          {primary.map((item, i) => {
            const Icon = Icons[primaryIcons[i]];
            const dark = i === 1;
            return (
              <Reveal
                key={i}
                delay={(Math.min(i, 2) as 0 | 1 | 2)}
                className={`flex flex-col gap-4 overflow-hidden rounded-2xl border p-8 transition-all hover:-translate-y-1 ${
                  dark
                    ? "border-line-dark bg-graphite-900 hover:shadow-glow"
                    : "border-line bg-surface hover:border-accent/30 hover:shadow-glow-sm"
                }`}
              >
                <span
                  className={`flex h-12 w-12 items-center justify-center rounded-xl ${
                    dark ? "bg-accent/15 text-accent-light" : "bg-accent/10 text-accent-dark"
                  }`}
                >
                  <Icon className="h-6 w-6" />
                </span>
                <h3
                  className={`text-xl font-semibold leading-tight ${
                    dark ? "text-white" : "text-graphite-800"
                  }`}
                >
                  {item.title}
                </h3>
                <p
                  className={`text-[15px] leading-relaxed ${
                    dark ? "text-faint" : "text-muted"
                  }`}
                >
                  {item.desc}
                </p>
                {dark && (
                  <span className="mt-auto w-fit rounded-full bg-accent/15 px-3 py-1 text-[11px] font-semibold tracking-wide text-accent-light">
                    {t("flagBadge")}
                  </span>
                )}
              </Reveal>
            );
          })}
        </div>

        <div className="mt-6 grid gap-6 md:grid-cols-2 lg:grid-cols-3">
          {secondary.map((item, i) => {
            const Icon = Icons[secondaryIcons[i]];
            return (
              <Reveal
                key={i}
                delay={(Math.min(i, 3) as 0 | 1 | 2 | 3)}
                className="flex items-start gap-4 rounded-2xl border border-line bg-surface p-7 transition-all hover:-translate-y-1 hover:border-accent/30 hover:shadow-glow-sm"
              >
                <span className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl bg-accent/10 text-accent-dark">
                  <Icon className="h-6 w-6" />
                </span>
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <h3 className="text-lg font-semibold text-graphite-800">
                      {item.title}
                    </h3>
                    {item.status && <StatusBadge status={item.status} />}
                  </div>
                  <p className="mt-2 text-sm leading-relaxed text-muted">
                    {item.desc}
                  </p>
                </div>
              </Reveal>
            );
          })}
        </div>
      </Container>
    </section>
  );
}
