"use client";

import { useLocale } from "next-intl";
import { usePathname, useRouter } from "@/i18n/navigation";
import { routing } from "@/i18n/routing";

export function LangSwitcher({
  variant = "dark",
}: {
  variant?: "dark" | "light";
}) {
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();

  const active =
    variant === "dark" ? "font-semibold text-white" : "font-semibold text-ink";
  const inactive =
    variant === "dark"
      ? "font-medium text-faint hover:text-white"
      : "font-medium text-muted hover:text-ink";

  return (
    <div className="flex items-center gap-1.5 text-[13px]">
      {routing.locales.map((loc, i) => (
        <span key={loc} className="flex items-center gap-1.5">
          {i > 0 && <span className="text-faint">/</span>}
          <button
            type="button"
            onClick={() => router.replace(pathname, { locale: loc })}
            className={`uppercase transition-colors ${
              loc === locale ? active : inactive
            }`}
          >
            {loc}
          </button>
        </span>
      ))}
    </div>
  );
}
