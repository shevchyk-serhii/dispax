import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { useTranslations } from "next-intl";
import { routing } from "@/i18n/routing";
import { MarketingPage } from "@/components/sections/MarketingPage";
import { PageHero } from "@/components/sections/marketing/PageHero";
import { Container } from "@/components/ui/Container";
import { StatusBadge, FeatureStatus } from "@/components/ui/StatusBadge";
import { Reveal } from "@/components/ui/Reveal";

const NS = "featuresPage";

type Item = { title: string; desc: string; status?: FeatureStatus };
type Group = { title: string; items: Item[] };

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: `${NS}.meta` });
  return { title: t("title"), description: t("description") };
}

function FeatureGroups() {
  const t = useTranslations(NS);
  const groups = t.raw("groups") as Group[];

  return (
    <section className="bg-bg py-24 md:py-28">
      <Container>
        <div className="flex flex-col gap-20">
          {groups.map((group, gi) => (
            <div key={gi}>
              <Reveal>
                <h2 className="text-2xl font-bold tracking-tight text-graphite-800 md:text-[28px]">
                  {group.title}
                </h2>
              </Reveal>
              <div className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                {group.items.map((item, i) => (
                  <Reveal
                    key={i}
                    delay={(Math.min(i, 3) as 0 | 1 | 2 | 3)}
                    className="flex flex-col rounded-2xl border border-line bg-surface p-7 transition-all hover:-translate-y-1 hover:border-accent/30 hover:shadow-glow-sm"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <h3 className="text-lg font-semibold text-graphite-800">
                        {item.title}
                      </h3>
                      {item.status && <StatusBadge status={item.status} />}
                    </div>
                    <p className="mt-2 text-sm leading-relaxed text-muted">
                      {item.desc}
                    </p>
                  </Reveal>
                ))}
              </div>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}

export default async function FeaturesPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations({ locale, namespace: `${NS}.hero` });

  return (
    <MarketingPage>
      <PageHero
        eyebrow={t("eyebrow")}
        title={t("title")}
        subtitle={t("subtitle")}
        ctaPrimary={{ label: t("ctaPrimary"), href: "/kontakt" }}
        ctaSecondary={{ label: t("ctaSecondary"), href: "/kontakt" }}
      />
      <FeatureGroups />
    </MarketingPage>
  );
}
