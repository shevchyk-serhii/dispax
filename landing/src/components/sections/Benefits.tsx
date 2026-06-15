import { useTranslations } from "next-intl";
import { Container } from "../ui/Container";
import { SectionHeader } from "../ui/SectionHeader";
import { Icons } from "../ui/icons";

type Item = { title: string; desc: string };
type Stat = { value: string; label: string };

export function Benefits() {
  const t = useTranslations("benefits");
  const items = t.raw("items") as Item[];
  const stats = t.raw("stats") as Stat[];

  return (
    <section
      id="benefits"
      className="relative scroll-mt-20 overflow-hidden bg-graphite-900 py-28"
    >
      <div className="pointer-events-none absolute inset-0" aria-hidden>
        <div className="absolute left-[100px] top-[160px] h-1 w-[1000px] rotate-[7deg] bg-accent opacity-40 blur-[55px]" />
        <div className="absolute left-[400px] top-[360px] h-1 w-[1100px] -rotate-8 bg-accent-light opacity-30 blur-[50px]" />
      </div>

      <Container className="relative">
        <SectionHeader eyebrow={t("eyebrow")} title={t("title")} dark />

        <div className="mt-14 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {items.map((item, i) => (
            <div
              key={i}
              className="rounded-xl border border-white/[0.08] bg-white/[0.03] p-7"
            >
              <Icons.check className="h-6 w-6 text-accent-light" />
              <h3 className="mt-2.5 text-[17px] font-semibold leading-snug text-white">
                {item.title}
              </h3>
              <p className="mt-2 text-sm leading-relaxed text-faint">
                {item.desc}
              </p>
            </div>
          ))}
        </div>

        <div className="mt-16 grid grid-cols-2 gap-8 lg:grid-cols-4">
          {stats.map((stat, i) => (
            <div key={i} className="flex flex-col items-center text-center">
              <span className="text-4xl font-bold tracking-tight text-white">
                {stat.value}
              </span>
              <span className="mt-1.5 text-sm text-faint">{stat.label}</span>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
