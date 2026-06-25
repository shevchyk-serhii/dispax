"use client";

import { useState } from "react";
import Image from "next/image";
import { DashboardMock } from "./DashboardMock";

const SRC = "/screenshots/dispatcher-dashboard.png";

/**
 * Real product screenshot for the hero, framed with an accent glow.
 * Falls back to the hand-built DashboardMock if the PNG is missing or fails to
 * load — so the page renders correctly even before the screenshot is captured.
 */
export function HeroScreenshot() {
  const [failed, setFailed] = useState(false);

  if (failed) {
    return <DashboardMock />;
  }

  return (
    <div className="overflow-hidden rounded-xl border border-white/15 bg-surface shadow-glow ring-1 ring-white/5">
      <Image
        src={SRC}
        alt="Dispax dispatcher dashboard — pending requests and driver schedule"
        width={2560}
        height={1600}
        priority
        sizes="(max-width: 1024px) 100vw, 1024px"
        className="h-auto w-full"
        onError={() => setFailed(true)}
      />
    </div>
  );
}
