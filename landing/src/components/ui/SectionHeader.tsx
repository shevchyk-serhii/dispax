export function SectionHeader({
  eyebrow,
  title,
  subtitle,
  dark = false,
}: {
  eyebrow: string;
  title: string;
  subtitle?: string;
  dark?: boolean;
}) {
  return (
    <div className="mx-auto flex max-w-2xl flex-col items-center text-center">
      <span
        className={`text-[13px] font-semibold tracking-wider ${
          dark ? "text-accent-light" : "text-accent-dark"
        }`}
      >
        {eyebrow}
      </span>
      <h2
        className={`mt-4 text-3xl font-bold leading-tight tracking-tight md:text-[40px] ${
          dark ? "text-white" : "text-graphite-800"
        }`}
      >
        {title}
      </h2>
      {subtitle && (
        <p
          className={`mt-4 text-[17px] leading-relaxed ${
            dark ? "text-faint" : "text-muted"
          }`}
        >
          {subtitle}
        </p>
      )}
    </div>
  );
}
