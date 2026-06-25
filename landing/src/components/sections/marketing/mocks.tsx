import { Icons } from "../../ui/icons";

/* ── Stylised product mock visuals (no real screenshots) ─────────────
   Shared by FeatureSpotlight (home) and the role/feature marketing pages.
   Polished, enlarged versions of the original FeatureSpotlight mocks. */

export function MockFrame({
  children,
  title,
}: {
  children: React.ReactNode;
  title?: string;
}) {
  return (
    <div className="overflow-hidden rounded-2xl border border-line bg-surface shadow-[0_30px_80px_-20px_rgba(14,165,233,0.28)]">
      <div className="flex items-center gap-2 border-b border-line bg-surface-variant/60 px-4 py-3">
        <span className="h-2.5 w-2.5 rounded-full bg-[#EF4444]" />
        <span className="h-2.5 w-2.5 rounded-full bg-[#F59E0B]" />
        <span className="h-2.5 w-2.5 rounded-full bg-[#10B981]" />
        {title && (
          <span className="ml-2 text-[12px] font-medium text-faint">{title}</span>
        )}
      </div>
      <div className="p-6">{children}</div>
    </div>
  );
}

export function EtaMock() {
  return (
    <MockFrame title="Live monitor">
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
                d.ok ? "bg-accent/15 text-accent-dark" : "bg-surface text-muted"
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

export function AirportMock() {
  const steps = [
    { label: "Landed", done: true },
    { label: "Baggage claim", done: true },
    { label: "Exit T2 · Meeting point", done: false },
  ];
  return (
    <MockFrame title="Airport coordination">
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

export function BillingMock() {
  const rows = [
    { date: "Jun 03", route: "MUC → Marienplatz", amount: "€48.00" },
    { date: "Jun 07", route: "Schwabing → HBF", amount: "€22.50" },
    { date: "Jun 11", route: "MUC T2 → Bogenhausen", amount: "€61.00" },
  ];
  return (
    <MockFrame title="Billing">
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

export function PoolsMock() {
  const members = [
    { name: "Mr. Weber", state: "Picked up" },
    { name: "Ms. Klein", state: "Confirmed" },
    { name: "Mr. Hahn", state: "Pending" },
  ];
  return (
    <MockFrame title="Pools & templates">
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

export function TrackingMock() {
  return (
    <MockFrame title="Live tracking">
      <div className="relative h-40 overflow-hidden rounded-xl bg-graphite-900">
        <div className="absolute inset-0 opacity-30 [background-image:linear-gradient(#27272a_1px,transparent_1px),linear-gradient(90deg,#27272a_1px,transparent_1px)] [background-size:24px_24px]" />
        <svg
          className="absolute inset-0 h-full w-full"
          viewBox="0 0 320 160"
          fill="none"
        >
          <path
            d="M40 130 C 110 120, 120 50, 200 50 S 280 40, 290 36"
            stroke="#0ea5e9"
            strokeWidth="3"
            strokeDasharray="2 8"
            strokeLinecap="round"
          />
        </svg>
        <span className="absolute left-[34px] top-[120px] flex h-4 w-4 items-center justify-center rounded-full bg-accent ring-4 ring-accent/25" />
        <span className="absolute right-[24px] top-[26px] flex h-5 w-5 items-center justify-center rounded-full bg-white text-graphite-900">
          <Icons.pin className="h-3.5 w-3.5" />
        </span>
      </div>
      <div className="mt-4 flex items-center justify-between rounded-lg bg-surface-variant px-3 py-2.5">
        <span className="text-[13px] font-semibold text-graphite-800">
          Stefan M. · BMW transfer
        </span>
        <span className="rounded-full bg-accent/15 px-2 py-0.5 text-[11px] font-semibold text-accent-dark">
          ETA 7 min
        </span>
      </div>
    </MockFrame>
  );
}

export function DispatchMock() {
  const rows = [
    { time: "09:30", route: "MUC → Marienplatz", urgent: false },
    { time: "10:15", route: "Schwabing → HBF", urgent: true },
  ];
  return (
    <MockFrame title="Manual dispatch">
      <p className="text-[12px] font-semibold tracking-wide text-muted">
        PENDING REQUESTS
      </p>
      <div className="mt-3 flex flex-col gap-2.5">
        {rows.map((r, i) => (
          <div
            key={i}
            className="flex items-center justify-between rounded-lg border border-line bg-surface px-3 py-2.5"
          >
            <div>
              <span className="text-[13px] font-bold text-graphite-800">
                {r.time}
              </span>
              <p className="text-[12px] text-muted">{r.route}</p>
            </div>
            <span
              className={`rounded-full px-2.5 py-1 text-[11px] font-semibold ${
                r.urgent
                  ? "bg-[#FEF2F2] text-[#991B1B]"
                  : "bg-accent/15 text-accent-dark"
              }`}
            >
              {r.urgent ? "Urgent" : "Assign"}
            </span>
          </div>
        ))}
      </div>
      <div className="mt-3 flex items-center gap-2 rounded-lg bg-surface-variant px-3 py-2.5">
        <Icons.check className="h-4 w-4 text-accent-dark" />
        <span className="text-[12px] font-medium text-muted">
          Travel-time validated · no conflict
        </span>
      </div>
    </MockFrame>
  );
}
