import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { useTranslations } from "next-intl";
import { routing } from "@/i18n/routing";
import { MarketingPage } from "@/components/sections/MarketingPage";
import { PageHero } from "@/components/sections/marketing/PageHero";
import { Container } from "@/components/ui/Container";
import { Reveal } from "@/components/ui/Reveal";
import { Icons } from "@/components/ui/icons";
import { Link } from "@/i18n/navigation";
import { localeAlternates } from "@/lib/site";

const NS = "about";
const PATH = "/about";

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
  return {
    title: t("title"),
    description: t("description"),
    alternates: localeAlternates(locale, PATH),
  };
}

function AboutBody() {
  const t = useTranslations(NS);

  return (
    <section className="bg-bg py-24 md:py-28">
      <Container>
        <div className="mx-auto flex max-w-3xl flex-col gap-14">
          <Reveal>
            <h2 className="text-2xl font-bold tracking-tight text-graphite-800 md:text-[28px]">
              {t("story.title")}
            </h2>
            <p className="mt-4 text-[17px] leading-relaxed text-muted">
              {t("story.body")}
            </p>
          </Reveal>

          <Reveal>
            <h2 className="text-2xl font-bold tracking-tight text-graphite-800 md:text-[28px]">
              {t("market.title")}
            </h2>
            <p className="mt-4 text-[17px] leading-relaxed text-muted">
              {t("market.body")}
            </p>
          </Reveal>

          <Reveal className="rounded-2xl border border-line bg-surface p-8">
            <h2 className="text-xl font-bold tracking-tight text-graphite-800">
              {t("identity.title")}
            </h2>
            <dl className="mt-4 flex flex-col gap-2 text-[15px]">
              <div className="flex gap-2">
                <Icons.users className="mt-0.5 h-4 w-4 shrink-0 text-accent-dark" />
                <span className="font-medium text-graphite-800">
                  {t("identity.provider")}
                </span>
              </div>
              <p className="pl-6 text-muted">{t("identity.legalForm")}</p>
              <p className="pl-6 text-muted">{t("identity.duns")}</p>
            </dl>
            <p className="mt-5 text-sm text-muted">
              {t("identity.note")}{" "}
              <Link
                href="/impressum"
                className="font-medium text-accent-dark hover:underline"
              >
                Impressum
              </Link>
            </p>
          </Reveal>
        </div>
      </Container>
    </section>
  );
}

export default async function AboutPage({
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
        ctaSecondary={{ label: t("ctaSecondary"), href: "/features" }}
      />
      <AboutBody />
    </MarketingPage>
  );
}
