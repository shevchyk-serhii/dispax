"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";
import { Container } from "./Container";
import { Logo } from "./Logo";
import { LangSwitcher } from "./LangSwitcher";

export function NavBar() {
  const t = useTranslations("nav");
  const [open, setOpen] = useState(false);

  const links = [
    { href: "#features", label: t("features") },
    { href: "#how", label: t("how") },
    { href: "#benefits", label: t("benefits") },
    { href: "#contact", label: t("contact") },
  ];

  return (
    <header className="relative z-20">
      <Container>
        <nav className="flex items-center justify-between py-6">
          <a href="#top" aria-label="Dispax">
            <Logo />
          </a>

          <div className="hidden items-center gap-8 lg:flex">
            {links.map((l) => (
              <a
                key={l.href}
                href={l.href}
                className="text-sm font-medium text-faint transition-colors hover:text-white"
              >
                {l.label}
              </a>
            ))}
          </div>

          <div className="hidden items-center gap-4 lg:flex">
            <LangSwitcher />
            <a
              href="#contact"
              className="rounded-md bg-accent px-6 py-3 text-[15px] font-semibold text-white transition-colors hover:bg-accent-dark"
            >
              {t("cta")}
            </a>
          </div>

          <button
            type="button"
            aria-label="Menu"
            aria-expanded={open}
            onClick={() => setOpen((v) => !v)}
            className="flex h-10 w-10 items-center justify-center text-white lg:hidden"
          >
            <span className="text-2xl leading-none">{open ? "✕" : "☰"}</span>
          </button>
        </nav>

        {open && (
          <div className="flex flex-col gap-4 pb-6 lg:hidden">
            {links.map((l) => (
              <a
                key={l.href}
                href={l.href}
                onClick={() => setOpen(false)}
                className="text-base font-medium text-faint hover:text-white"
              >
                {l.label}
              </a>
            ))}
            <div className="flex items-center justify-between pt-2">
              <LangSwitcher />
              <a
                href="#contact"
                onClick={() => setOpen(false)}
                className="rounded-md bg-accent px-6 py-3 text-[15px] font-semibold text-white"
              >
                {t("cta")}
              </a>
            </div>
          </div>
        )}
      </Container>
    </header>
  );
}
