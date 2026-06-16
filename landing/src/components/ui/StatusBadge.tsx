import { useTranslations } from "next-intl";

export type FeatureStatus = "live" | "soon";

export function StatusBadge({
  status,
  className = "",
}: {
  status: FeatureStatus;
  className?: string;
}) {
  const t = useTranslations("badges");

  if (status === "live") {
    return (
      <span
        className={`inline-flex w-fit items-center gap-1.5 rounded-full bg-accent/15 px-2.5 py-1 text-[11px] font-semibold tracking-wide text-accent-dark ${className}`}
      >
        <span className="h-1.5 w-1.5 rounded-full bg-accent" />
        {t("live")}
      </span>
    );
  }

  return (
    <span
      className={`inline-flex w-fit items-center gap-1.5 rounded-full bg-surface-variant px-2.5 py-1 text-[11px] font-semibold tracking-wide text-muted ${className}`}
    >
      <span className="h-1.5 w-1.5 rounded-full bg-faint" />
      {t("soon")}
    </span>
  );
}
