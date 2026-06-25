import { useTranslations } from "next-intl";
import { Container } from "../ui/Container";
import { Logo } from "../ui/Logo";
import { Link } from "@/i18n/navigation";

export function Footer() {
  const t = useTranslations("footer");

  const productLinks = [
    { href: "#features", label: t("links.features") },
    { href: "#how", label: t("links.how") },
    { href: "#benefits", label: t("links.benefits") },
  ];
  const companyLinks = [
    { href: "#contact", label: t("links.contact") },
    { href: "/impressum", label: t("links.imprint"), internal: true },
    { href: "/datenschutz", label: t("links.privacy"), internal: true },
  ];

  return (
    <footer className="bg-graphite-900 pb-10 pt-14">
      <Container>
        <div className="flex flex-col justify-between gap-10 md:flex-row">
          <div className="max-w-xs">
            <Logo />
            <p className="mt-3 text-sm leading-relaxed text-faint">
              {t("tagline")}
            </p>
          </div>

          <div className="flex flex-wrap gap-12">
            <FooterCol title={t("product")} links={productLinks} />
            <FooterCol title={t("company")} links={companyLinks} />
            <div className="flex flex-col gap-3">
              <p className="text-[13px] font-semibold tracking-wide text-faint">
                {t("contact")}
              </p>
              <a
                href="mailto:hallo@dispax.de"
                className="text-sm text-accent-light hover:underline"
              >
                hallo@dispax.de
              </a>
              <span className="text-sm text-faint">{t("city")}</span>
            </div>
          </div>
        </div>

        <div className="mt-8 flex flex-col items-start justify-between gap-3 border-t border-line-dark pt-7 sm:flex-row sm:items-center">
          <span className="text-[13px] text-faint">{t("copyright")}</span>
          <span className="text-[13px] text-faint">{t("langs")}</span>
        </div>
      </Container>
    </footer>
  );
}

function FooterCol({
  title,
  links,
}: {
  title: string;
  links: { href: string; label: string; internal?: boolean }[];
}) {
  const linkClass =
    "text-sm text-faint transition-colors hover:text-white";
  return (
    <div className="flex flex-col gap-3">
      <p className="text-[13px] font-semibold tracking-wide text-faint">
        {title}
      </p>
      {links.map((l, i) =>
        l.internal ? (
          <Link key={i} href={l.href} className={linkClass}>
            {l.label}
          </Link>
        ) : (
          <a key={i} href={l.href} className={linkClass}>
            {l.label}
          </a>
        ),
      )}
    </div>
  );
}
