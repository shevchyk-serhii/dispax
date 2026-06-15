import { setRequestLocale } from "next-intl/server";
import { Hero } from "@/components/sections/Hero";
import { Problem } from "@/components/sections/Problem";
import { Features } from "@/components/sections/Features";
import { HowItWorks } from "@/components/sections/HowItWorks";
import { Benefits } from "@/components/sections/Benefits";
import { CtaWaitlist } from "@/components/sections/CtaWaitlist";
import { Footer } from "@/components/sections/Footer";

export default async function Home({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);

  return (
    <main>
      <Hero />
      <Problem />
      <Features />
      <HowItWorks />
      <Benefits />
      <CtaWaitlist />
      <Footer />
    </main>
  );
}
