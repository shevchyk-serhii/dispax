import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { routing } from "@/i18n/routing";
import { MarketingPage } from "@/components/sections/MarketingPage";
import { RolePageContent } from "@/components/sections/marketing/RolePageContent";
import { IconName } from "@/components/ui/icons";
import {
  TrackingMock,
  AirportMock,
  PoolsMock,
} from "@/components/sections/marketing/mocks";
import { localeAlternates } from "@/lib/site";

const NS = "forDrivers";
const PATH = "/for-drivers";
const icons: IconName[] = ["steering", "planeLand", "pin", "calendarCheck", "users"];

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

export default async function ForDriversPage({
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
        heroVisual={<TrackingMock />}
        rowVisuals={[<AirportMock key="air" />, <TrackingMock key="trk" />, <PoolsMock key="pool" />]}
      />
    </MarketingPage>
  );
}
