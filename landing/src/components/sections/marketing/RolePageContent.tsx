import { useTranslations } from "next-intl";
import { Container } from "../../ui/Container";
import { Link } from "@/i18n/navigation";
import { IconName } from "../../ui/icons";
import { FeatureStatus } from "../../ui/StatusBadge";
import { Reveal } from "../../ui/Reveal";
import { PageHero } from "./PageHero";
import { FeatureRow } from "./FeatureRow";

type Row = {
  title: string;
  desc: string;
  status?: FeatureStatus;
  bullets: string[];
};

/**
 * Renders a full role landing page (hero + alternating feature rows + CTA)
 * from a single i18n namespace. `icons` and `visuals` are positional, matched
 * to the `rows` array by index.
 */
export function RolePageContent({
  namespace,
  icons,
  heroVisual,
  rowVisuals,
}: {
  namespace: string;
  icons: IconName[];
  heroVisual: React.ReactNode;
  rowVisuals: React.ReactNode[];
}) {
  const t = useTranslations(namespace);
  const rows = t.raw("rows") as Row[];

  return (
    <>
      <PageHero
        eyebrow={t("hero.eyebrow")}
        title={t("hero.title")}
        subtitle={t("hero.subtitle")}
        ctaPrimary={{ label: t("hero.ctaPrimary"), href: "/kontakt" }}
        ctaSecondary={{ label: t("hero.ctaSecondary"), href: "/features" }}
        visual={heroVisual}
      />

      <section className="bg-bg py-24 md:py-28">
        <Container>
          <div className="flex flex-col gap-24">
            {rows.map((row, i) => (
              <FeatureRow
                key={i}
                index={i}
                icon={icons[i]}
                title={row.title}
                desc={row.desc}
                bullets={row.bullets}
                status={row.status}
                visual={rowVisuals[i % rowVisuals.length]}
              />
            ))}
          </div>
        </Container>
      </section>

      <section className="bg-accent-wash bg-surface py-24">
        <Container>
          <Reveal className="mx-auto flex max-w-2xl flex-col items-center text-center">
            <h2 className="text-3xl font-bold tracking-tight text-graphite-800 md:text-[36px]">
              {t("cta.title")}
            </h2>
            <p className="mt-4 text-[17px] leading-relaxed text-muted">
              {t("cta.subtitle")}
            </p>
            <Link
              href="/kontakt"
              className="mt-8 inline-flex items-center justify-center rounded-md bg-accent px-7 py-3.5 text-[15px] font-semibold text-white transition-colors hover:bg-accent-dark"
            >
              {t("hero.ctaPrimary")}
            </Link>
          </Reveal>
        </Container>
      </section>
    </>
  );
}
