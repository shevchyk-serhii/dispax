import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { routing } from "@/i18n/routing";
import { LegalPage, LegalBlock } from "@/components/sections/LegalPage";

export function generateStaticParams() {
  return routing.locales.map((locale) => ({ locale }));
}

export async function generateMetadata({
  params,
}: {
  params: Promise<{ locale: string }>;
}): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "legal.privacy" });
  return { title: `${t("title")} — Dispax` };
}

export default async function DatenschutzPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = await getTranslations({ locale, namespace: "legal.privacy" });

  return (
    <LegalPage title={t("title")}>
      <LegalBlock text={t("intro")} />
      <LegalBlock label={t("controllerLabel")} text={t("controller")} />
      <LegalBlock label={t("collectLabel")} text={t("collect")} />
      <LegalBlock label={t("purposeLabel")} text={t("purpose")} />
      <LegalBlock label={t("retentionLabel")} text={t("retention")} />
      <LegalBlock label={t("rightsLabel")} text={t("rights")} />
      <LegalBlock label={t("hostingLabel")} text={t("hosting")} />
    </LegalPage>
  );
}
