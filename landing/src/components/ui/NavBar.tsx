"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { Container } from "./Container";
import { Logo } from "./Logo";
import { LangSwitcher } from "./LangSwitcher";
import { Link } from "@/i18n/navigation";
import { Icons } from "./icons";

type Variant = "dark" | "light";

/**
 * Global navigation, used on the dark home Hero (variant="dark") and on the
 * light marketing sub-pages (variant="light", sticky + blurred surface).
 *
 * Internal routes use locale-aware <Link>; home sections use "/#anchor" links
 * so they resolve from any page (navigate home, then jump to the section).
 */
export function NavBar({ variant = "dark" }: { variant?: Variant }) {
  const t = useTranslations("nav");
  const [open, setOpen] = useState(false);
  const [solutionsOpen, setSolutionsOpen] = useState(false);
  const solutionsRef = useRef<HTMLDivElement>(null);
  const dark = variant === "dark";

  const solutions = [
    { href: "/for-dispatchers", label: t("forDispatchers") },
    { href: "/for-drivers", label: t("forDrivers") },
    { href: "/for-clients", label: t("forClients") },
  ];
  const links = [
    { href: "/features", label: t("features") },
    { href: "/about", label: t("about") },
    { href: "/kontakt", label: t("contact") },
  ];

  // Close the Solutions dropdown on outside click or Escape.
  useEffect(() => {
    if (!solutionsOpen) return;
    function onClick(e: MouseEvent) {
      if (solutionsRef.current && !solutionsRef.current.contains(e.target as Node)) {
        setSolutionsOpen(false);
      }
    }
    function onKey(e: KeyboardEvent) {
      if (e.key === "Escape") setSolutionsOpen(false);
    }
    document.addEventListener("mousedown", onClick);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onClick);
      document.removeEventListener("keydown", onKey);
    };
  }, [solutionsOpen]);

  const linkClass = dark
    ? "text-sm font-medium text-faint transition-colors hover:text-white"
    : "text-sm font-medium text-muted transition-colors hover:text-ink";

  const header = dark
    ? "relative z-20"
    : "sticky top-0 z-30 border-b border-line bg-surface/80 backdrop-blur-md";

  return (
    <header className={header}>
      <Container>
        <nav className="flex items-center justify-between py-5">
          <Link href="/" aria-label="Dispax">
            <Logo dark={!dark} />
          </Link>

          <div className="hidden items-center gap-7 lg:flex">
            {/* Solutions dropdown */}
            <div className="relative" ref={solutionsRef}>
              <button
                type="button"
                aria-haspopup="true"
                aria-expanded={solutionsOpen}
                aria-controls="solutions-menu"
                onClick={() => setSolutionsOpen((v) => !v)}
                className={`flex items-center gap-1.5 ${linkClass}`}
              >
                {t("solutions")}
                <Icons.chevronDown
                  className={`h-3.5 w-3.5 transition-transform ${
                    solutionsOpen ? "rotate-180" : ""
                  }`}
                />
              </button>
              {solutionsOpen && (
                <div
                  id="solutions-menu"
                  className="absolute left-0 top-full mt-3 w-60 overflow-hidden rounded-xl border border-line bg-surface p-1.5 shadow-[0_20px_50px_rgba(9,9,11,0.15)]"
                >
                  {solutions.map((s) => (
                    <Link
                      key={s.href}
                      href={s.href}
                      onClick={() => setSolutionsOpen(false)}
                      className="block rounded-lg px-3 py-2.5 text-sm font-medium text-graphite-800 transition-colors hover:bg-surface-variant"
                    >
                      {s.label}
                    </Link>
                  ))}
                </div>
              )}
            </div>

            {links.map((l) => (
              <Link key={l.href} href={l.href} className={linkClass}>
                {l.label}
              </Link>
            ))}
          </div>

          <div className="hidden items-center gap-4 lg:flex">
            <LangSwitcher variant={variant} />
            <Link
              href="/kontakt"
              className="rounded-md bg-accent px-5 py-2.5 text-[15px] font-semibold text-white transition-colors hover:bg-accent-dark"
            >
              {t("cta")}
            </Link>
          </div>

          <button
            type="button"
            aria-label="Menu"
            aria-expanded={open}
            aria-controls="mobile-menu"
            onClick={() => setOpen((v) => !v)}
            className={`flex h-10 w-10 items-center justify-center lg:hidden ${
              dark ? "text-white" : "text-ink"
            }`}
          >
            <span className="text-2xl leading-none">{open ? "✕" : "☰"}</span>
          </button>
        </nav>

        {open && (
          <div id="mobile-menu" className="flex flex-col gap-1 pb-6 lg:hidden">
            <p
              className={`pb-1 pt-2 text-[11px] font-semibold uppercase tracking-wider ${
                dark ? "text-faint" : "text-faint"
              }`}
            >
              {t("solutions")}
            </p>
            {solutions.map((s) => (
              <Link
                key={s.href}
                href={s.href}
                onClick={() => setOpen(false)}
                className={`py-1.5 pl-3 text-base font-medium ${linkClass}`}
              >
                {s.label}
              </Link>
            ))}
            <div className={`my-3 h-px ${dark ? "bg-line-dark" : "bg-line"}`} />
            {links.map((l) => (
              <Link
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className={`py-1.5 text-base ${linkClass}`}
              >
                {l.label}
              </Link>
            ))}
            <div className="mt-4 flex items-center justify-between pt-2">
              <LangSwitcher variant={variant} />
              <Link
                href="/kontakt"
                onClick={() => setOpen(false)}
                className="rounded-md bg-accent px-5 py-2.5 text-[15px] font-semibold text-white"
              >
                {t("cta")}
              </Link>
            </div>
          </div>
        )}
      </Container>
    </header>
  );
}
