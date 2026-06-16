import { useTranslations } from "next-intl";
import { Container } from "../ui/Container";
import { SectionHeader } from "../ui/SectionHeader";
import { Icons, IconName } from "../ui/icons";
import { StatusBadge, FeatureStatus } from "../ui/StatusBadge";

type Block = {
  title: string;
  desc: string;
  bullets: string[];
  status: FeatureStatus;
};

const blockIcons: IconName[] = ["radar", "planeLand", "receipt", "layers"];
const mocks = [EtaMock, AirportMock, BillingMock, PoolsMock];

export function FeatureSpotlight() {
  const t = useTranslations("spotlight");
  const blocks = t.raw("blocks") as Block[];

  return (
    <section id="spotlight" className="scroll-mt-20 bg-bg py-28">
      <Container>
        <SectionHeader
          eyebrow={t("eyebrow")}
          title={t("title")}
          subtitle={t("subtitle")}
        />

        <div className="mt-20 flex flex-col gap-24">
          {blocks.map((block, i) => {
            const Icon = Icons[blockIcons[i]];
            const Mock = mocks[i];
            const reversed = i % 2 === 1;
            return (
              <div
                key={i}
                className="grid items-center gap-10 lg:grid-cols-2 lg:gap-16"
              >
                <div className={reversed ? "lg:order-2" : ""}>
                  <span className="flex h-12 w-12 items-center justify-center rounded-xl bg-accent/10 text-accent-dark">
                    <Icon className="h-6 w-6" />
                  </span>
                  <div className="mt-5 flex items-center gap-3">
                    <h3 className="text-2xl font-bold tracking-tight text-graphite-800 md:text-[28px]">
                      {block.title}
                    </h3>
                    <StatusBadge status={block.status} />
                  </div>
                  <p className="mt-4 text-[17px] leading-relaxed text-muted">
                    {block.desc}
                  </p>
                  <ul className="mt-6 flex flex-col gap-3">
                    {block.bullets.map((b, j) => (
                      <li key={j} className="flex items-start gap-3">
                        <span className="mt-0.5 flex h-5 w-5 shrink-0 items-center justify-center rounded-full bg-accent/10 text-accent-dark">
                          <Icons.check className="h-3.5 w-3.5" />
                        </span>
                        <span className="text-[15px] leading-relaxed text-graphite-800">
                          {b}
                        </span>
                      </li>
                    ))}
                  </ul>
                </div>

                <div className={reversed ? "lg:order-1" : ""}>
                  <Mock />
                </div>
              </div>
            );
          })}
        </div>
      </Container>
    </section>
  );
}

/* ── Stylised mock visuals (no real screenshots) ─────────────── */

function MockFrame({ children }: { children: React.ReactNode }) {
  return (
    <div className="overflow-hidden rounded-2xl border border-line bg-surface shadow-[0_20px_60px_rgba(14,165,233,0.12)]">
      <div className="flex items-center gap-2 border-b border-line px-4 py-3">
        <span className="h-2.5 w-2.5 rounded-full bg-[#EF4444]" />
        <span className="h-2.5 w-2.5 rounded-full bg-[#F59E0B]" />
        <span className="h-2.5 w-2.5 rounded-full bg-[#10B981]" />
      </div>
      <div className="p-5">{children}</div>
    </div>
  );
}

function EtaMock() {
  return (
    <MockFrame>
      <div className="rounded-xl border border-[#FECACA] bg-[#FEF2F2] p-4">
        <div className="flex items-center justify-between">
          <span className="flex items-center gap-2 text-[13px] font-bold text-[#991B1B]">
            <span className="h-2 w-2 animate-pulse rounded-full bg-[#EF4444]" />
            ETA AT RISK
          </span>
          <span className="text-[11px] font-semibold text-[#B91C1C]">
            slack&nbsp;−3 min
          </span>
        </div>
        <p className="mt-2 text-sm font-semibold text-graphite-800">
          MUC T2 → Bogenhausen · BMW AG
        </p>
        <p className="mt-0.5 text-xs text-[#991B1B]">
          Driver Tomas R. won&apos;t make 11:00 pickup
        </p>
      </div>
      <div className="mt-4 flex flex-col gap-2">
        {[
          { name: "Stefan M.", eta: "+6 min", ok: true },
          { name: "Anna K.", eta: "+11 min", ok: false },
        ].map((d, i) => (
          <div
            key={i}
            className="flex items-center justify-between rounded-lg bg-surface-variant px-3 py-2.5"
          >
            <span className="text-[13px] font-semibold text-graphite-800">
              {d.name}
            </span>
            <span
              className={`rounded-full px-2 py-0.5 text-[11px] font-semibold ${
                d.ok
                  ? "bg-accent/15 text-accent-dark"
                  : "bg-surface text-muted"
              }`}
            >
              {d.eta}
            </span>
          </div>
        ))}
      </div>
    </MockFrame>
  );
}

function AirportMock() {
  const steps = [
    { label: "Landed", done: true },
    { label: "Baggage claim", done: true },
    { label: "Exit T2 · Meeting point", done: false },
  ];
  return (
    <MockFrame>
      <div className="flex items-center justify-between rounded-xl bg-graphite-900 px-4 py-3">
        <span className="text-[13px] font-semibold text-white">
          MUC Airport · Geofence
        </span>
        <span className="rounded-full bg-accent/20 px-2 py-0.5 text-[11px] font-semibold text-accent-light">
          1.0 km
        </span>
      </div>
      <div className="mt-4 flex flex-col gap-0">
        {steps.map((s, i) => (
          <div key={i} className="flex items-start gap-3">
            <div className="flex flex-col items-center">
              <span
                className={`flex h-5 w-5 items-center justify-center rounded-full ${
                  s.done
                    ? "bg-accent text-white"
                    : "border-2 border-accent bg-surface"
                }`}
              >
                {s.done && <Icons.check className="h-3 w-3" />}
              </span>
              {i < steps.length - 1 && (
                <span className="my-0.5 h-6 w-0.5 bg-line" />
              )}
            </div>
            <span
              className={`pt-0.5 text-[13px] ${
                s.done
                  ? "font-medium text-muted"
                  : "font-semibold text-graphite-800"
              }`}
            >
              {s.label}
            </span>
          </div>
        ))}
      </div>
      <div className="mt-4 rounded-lg bg-surface-variant px-3 py-2.5 text-center">
        <span className="text-[11px] font-medium text-muted">
          Optimal entry · save{" "}
        </span>
        <span className="text-[13px] font-bold text-accent-dark">€12.50</span>
        <span className="text-[11px] font-medium text-muted"> on parking</span>
      </div>
    </MockFrame>
  );
}

function BillingMock() {
  const rows = [
    { date: "Jun 03", route: "MUC → Marienplatz", amount: "€48.00" },
    { date: "Jun 07", route: "Schwabing → HBF", amount: "€22.50" },
    { date: "Jun 11", route: "MUC T2 → Bogenhausen", amount: "€61.00" },
  ];
  return (
    <MockFrame>
      <div className="flex items-center justify-between">
        <span className="text-[13px] font-bold text-graphite-800">
          Invoice · BMW AG
        </span>
        <span className="rounded-full bg-accent/15 px-2 py-0.5 text-[11px] font-semibold text-accent-dark">
          Auto-filled
        </span>
      </div>
      <div className="mt-3 flex flex-col gap-1.5">
        {rows.map((r, i) => (
          <div
            key={i}
            className="flex items-center justify-between rounded-lg bg-surface-variant px-3 py-2"
          >
            <span className="text-[11px] font-medium text-faint">{r.date}</span>
            <span className="flex-1 px-3 text-[12px] text-graphite-800">
              {r.route}
            </span>
            <span className="text-[12px] font-semibold text-graphite-800">
              {r.amount}
            </span>
          </div>
        ))}
      </div>
      <div className="mt-3 flex items-center justify-between border-t border-line pt-3">
        <span className="rounded bg-graphite-900 px-2 py-1 text-[11px] font-semibold text-accent-light">
          DATEV export
        </span>
        <span className="text-sm font-bold text-graphite-800">€131.50</span>
      </div>
    </MockFrame>
  );
}

function PoolsMock() {
  const members = [
    { name: "Mr. Weber", state: "Picked up" },
    { name: "Ms. Klein", state: "Confirmed" },
    { name: "Mr. Hahn", state: "Pending" },
  ];
  return (
    <MockFrame>
      <div className="flex items-center justify-between rounded-xl bg-graphite-900 px-4 py-3">
        <span className="text-[13px] font-semibold text-white">
          Pool · Airport run
        </span>
        <span className="text-[11px] font-medium text-faint">3 / 4 seats</span>
      </div>
      <div className="mt-4 flex flex-col gap-2">
        {members.map((m, i) => (
          <div
            key={i}
            className="flex items-center justify-between rounded-lg bg-surface-variant px-3 py-2.5"
          >
            <span className="text-[13px] font-semibold text-graphite-800">
              {m.name}
            </span>
            <span className="text-[11px] font-medium text-muted">{m.state}</span>
          </div>
        ))}
      </div>
      <div className="mt-4 flex items-center gap-2 rounded-lg border border-dashed border-line px-3 py-2.5">
        <Icons.calendarCheck className="h-4 w-4 text-accent-dark" />
        <span className="text-[12px] font-medium text-muted">
          Template · Mon–Fri 08:00
        </span>
      </div>
    </MockFrame>
  );
}
