import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { routing } from "@/i18n/routing";
import { MarketingPage } from "@/components/sections/MarketingPage";
import { RolePageContent } from "@/components/sections/marketing/RolePageContent";
import { IconName } from "@/components/ui/icons";
import {
  DispatchMock,
  EtaMock,
  AirportMock,
  BillingMock,
} from "@/components/sections/marketing/mocks";
import { localeAlternates } from "@/lib/site";

const NS = "forDispatchers";
const PATH = "/for-dispatchers";
const icons: IconName[] = ["dashboard", "radar", "swap", "receipt", "shield"];

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

export default async function ForDispatchersPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <MarketingPage>
      <RolePageContent
        namespace={NS}
        icons={icons}
        heroVisual={<DispatchMock />}
        rowVisuals={[<EtaMock key="eta" />, <AirportMock key="air" />, <BillingMock key="bill" />]}
      />
    </MarketingPage>
  );
}
