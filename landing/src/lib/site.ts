/** Public base URL of the marketing site, used for metadata and sitemap. */
export const SITE_URL =
  process.env.NEXT_PUBLIC_SITE_URL?.replace(/\/$/, "") ?? "https://dispax.de";

/** Marketing routes (relative, without locale prefix) included in the sitemap. */
export const ROUTES = [
  "",
  "/features",
  "/for-dispatchers",
  "/for-drivers",
  "/for-clients",
  "/about",
  "/kontakt",
  "/impressum",
  "/datenschutz",
];

const LOCALES = ["de", "en"] as const;

/**
 * Canonical + hreflang alternates for a page at `path` (locale-prefix-free,
 * e.g. "/features" or "" for home) in the given `locale`.
 */
export function localeAlternates(locale: string, path: string) {
  return {
    canonical: `/${locale}${path}`,
    languages: Object.fromEntries(LOCALES.map((l) => [l, `/${l}${path}`])),
  };
}
