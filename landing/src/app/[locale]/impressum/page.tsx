import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { routing } from "@/i18n/routing";
import { LegalPage, LegalBlock } from "@/components/sections/LegalPage";
import { localeAlternates } from "@/lib/site";

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "legal.imprint" });
  return {
    title: `${t("title")} — Dispax`,
    alternates: localeAlternates(locale, "/impressum"),
  };
}

export default async function ImpressumPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations({ locale, namespace: "legal.imprint" });

  return (
    <LegalPage title={t("title")}>
      <LegalBlock text={t("intro")} />
      <LegalBlock label={t("providerLabel")} text={`${t("provider")}\n${t("legalForm")}`} />
      <LegalBlock label={t("addressLabel")} text={t("address")} />
      <LegalBlock label={t("contactLabel")} text={`${t("phone")}\n${t("email")}`} />
      <LegalBlock label={t("responsibleLabel")} text={t("responsible")} />
      <LegalBlock label={t("disputeLabel")} text={t("dispute")} />
      <LegalBlock label={t("liabilityLabel")} text={t("liability")} />
    </LegalPage>
  );
}
