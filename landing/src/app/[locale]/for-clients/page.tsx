import type { Metadata } from "next";
import { getTranslations, setRequestLocale } from "next-intl/server";
import { routing } from "@/i18n/routing";
import { MarketingPage } from "@/components/sections/MarketingPage";
import { RolePageContent } from "@/components/sections/marketing/RolePageContent";
import { IconName } from "@/components/ui/icons";
import {
  TrackingMock,
  AirportMock,
  EtaMock,
} from "@/components/sections/marketing/mocks";

const NS = "forClients";
const icons: IconName[] = ["pin", "radar", "planeLand", "clock", "shield"];

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

export default async function ForClientsPage({
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
        rowVisuals={[<TrackingMock key="trk" />, <EtaMock key="eta" />, <AirportMock key="air" />]}
      />
    </MarketingPage>
  );
}
