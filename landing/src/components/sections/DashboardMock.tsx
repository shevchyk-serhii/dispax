import { useTranslations } from "next-intl";

type Ride = { time: string; route: string; client: string; urgent: boolean };
type Driver = { name: string; status: string };

const driverDots = ["#10B981", "#F59E0B", "#EF4444"];
const driverBlocks: { c: string; s: number; e: number }[][] = [
  [
    { c: "#3B82F6", s: 0.15, e: 0.35 },
    { c: "#14B8A6", s: 0.45, e: 0.7 },
  ],
  [
    { c: "#10B981", s: 0.05, e: 0.25 },
    { c: "#3B82F6", s: 0.4, e: 0.55 },
    { c: "#F59E0B", s: 0.65, e: 0.95 },
  ],
  [
    { c: "#14B8A6", s: 0.0, e: 0.3 },
    { c: "#3B82F6", s: 0.32, e: 0.6 },
    { c: "#10B981", s: 0.62, e: 1.0 },
  ],
];

export function DashboardMock() {
  const t = useTranslations("hero.dashboard");
  const rides = t.raw("rides") as Ride[];
  const drivers = t.raw("drivers") as Driver[];

  return (
    <div className="overflow-hidden rounded-xl border border-white/15 bg-surface shadow-[0_20px_80px_rgba(14,165,233,0.2)]">
      {/* topbar */}
      <div className="flex items-center justify-between border-b border-line px-[18px] py-3.5">
        <div className="flex items-center gap-2">
          <span className="h-[11px] w-[11px] rounded-full bg-[#EF4444]" />
          <span className="h-[11px] w-[11px] rounded-full bg-[#F59E0B]" />
          <span className="h-[11px] w-[11px] rounded-full bg-[#10B981]" />
        </div>
        <span className="text-[13px] font-semibold text-muted">{t("title")}</span>
        <span className="text-[13px] font-medium text-faint">{t("meta")}</span>
      </div>

      <div className="flex flex-col sm:flex-row">
        {/* pending column */}
        <div className="border-b border-line bg-surface-variant p-[18px] sm:w-[340px] sm:border-b-0 sm:border-r">
          <p className="text-[13px] font-semibold tracking-wide text-muted">
            {t("pending")}
          </p>
          <div className="mt-3 flex flex-col gap-3">
            {rides.map((r, i) => (
              <div
                key={i}
                className="rounded-lg border border-line bg-surface p-3"
              >
                <div className="flex items-center justify-between">
                  <span className="text-sm font-bold text-graphite-800">
                    {r.time}
                  </span>
                  <span
                    className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${
                      r.urgent
                        ? "bg-[#FEF2F2] text-[#991B1B]"
                        : "bg-[#FFFBEB] text-[#92400E]"
                    }`}
                  >
                    {r.urgent ? t("urgent") : t("open")}
                  </span>
                </div>
                <p className="mt-1.5 text-[13px] font-medium text-graphite-800">
                  {r.route}
                </p>
                <p className="text-xs text-muted">{r.client}</p>
              </div>
            ))}
          </div>
        </div>

        {/* schedule column */}
        <div className="flex-1 p-[18px]">
          <p className="text-[13px] font-semibold tracking-wide text-muted">
            {t("schedule")}
          </p>
          <div className="mt-3 flex flex-col gap-3">
            {drivers.map((d, i) => (
              <div key={i} className="rounded-lg bg-surface-variant p-3">
                <div className="flex items-center gap-2">
                  <span
                    className="h-[9px] w-[9px] rounded-full"
                    style={{ backgroundColor: driverDots[i] }}
                  />
                  <span className="text-[13px] font-semibold text-graphite-800">
                    {d.name}
                  </span>
                  <span className="text-[11px] font-medium text-faint">
                    {d.status}
                  </span>
                </div>
                <div className="relative mt-2 h-[22px] overflow-hidden rounded bg-line">
                  {driverBlocks[i].map((b, j) => (
                    <span
                      key={j}
                      className="absolute top-0 h-[22px] rounded"
                      style={{
                        left: `${b.s * 100}%`,
                        width: `${(b.e - b.s) * 100}%`,
                        backgroundColor: b.c,
                      }}
                    />
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
