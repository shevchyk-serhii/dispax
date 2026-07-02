import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { useTranslations } from "next-intl";
import { routing } from "@/i18n/routing";
import { MarketingPage } from "@/components/sections/MarketingPage";
import { PageHero } from "@/components/sections/marketing/PageHero";
import { Container } from "@/components/ui/Container";
import { Reveal } from "@/components/ui/Reveal";
import { Icons } from "@/components/ui/icons";
import { ContactForm } from "@/components/sections/ContactForm";
import { localeAlternates } from "@/lib/site";

const NS = "kontakt";
const PATH = "/kontakt";

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

function ContactBody() {
  const t = useTranslations(`${NS}.direct`);

  return (
    <section className="bg-bg py-24 md:py-28">
      <Container>
        <div className="grid gap-12 lg:grid-cols-[1.4fr_1fr] lg:gap-16">
          <Reveal className="rounded-2xl border border-line bg-surface p-8 shadow-glow-sm">
            <ContactForm />
          </Reveal>

          <Reveal delay={1}>
            <h2 className="text-lg font-semibold text-graphite-800">
              {t("title")}
            </h2>
            <div className="mt-5 flex flex-col gap-4">
              <a
                href="mailto:hallo@dispax.de"
                className="flex items-center gap-3 text-[15px] text-graphite-800 hover:text-accent-dark"
              >
                <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent/10 text-accent-dark">
                  <Icons.mail className="h-4 w-4" />
                </span>
                {t("email")}
              </a>
              <a
                href="tel:+4917648733359"
                className="flex items-center gap-3 text-[15px] text-graphite-800 hover:text-accent-dark"
              >
                <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent/10 text-accent-dark">
                  <Icons.phone className="h-4 w-4" />
                </span>
                {t("phone")}
              </a>
              <div className="flex items-center gap-3 text-[15px] text-muted">
                <span className="flex h-9 w-9 items-center justify-center rounded-lg bg-accent/10 text-accent-dark">
                  <Icons.pin className="h-4 w-4" />
                </span>
                {t("city")}
              </div>
            </div>
          </Reveal>
        </div>
      </Container>
    </section>
  );
}

export default async function KontaktPage({
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
      />
      <ContactBody />
    </MarketingPage>
  );
}
