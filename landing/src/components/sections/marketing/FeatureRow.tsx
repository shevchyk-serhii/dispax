import { ReactNode } from "react";
import { Icons, IconName } from "../../ui/icons";
import { StatusBadge, FeatureStatus } from "../../ui/StatusBadge";
import { Reveal } from "../../ui/Reveal";

/**
 * Two-column feature block (icon + title + status + desc + check-bullets on one
 * side, a visual mock on the other), alternating sides by index. Extracted from
 * the home FeatureSpotlight layout so role/feature pages reuse the exact shape.
 */
export function FeatureRow({
  icon,
  title,
  desc,
  bullets,
  status,
  visual,
  index = 0,
}: {
  icon: IconName;
  title: string;
  desc: string;
  bullets: string[];
  status?: FeatureStatus;
  visual: ReactNode;
  index?: number;
}) {
  const Icon = Icons[icon];
  const reversed = index % 2 === 1;

  return (
    <div className="grid items-center gap-10 lg:grid-cols-2 lg:gap-16">
      <Reveal className={reversed ? "lg:order-2" : ""}>
        <span className="flex h-12 w-12 items-center justify-center rounded-xl bg-accent/10 text-accent-dark">
          <Icon className="h-6 w-6" />
        </span>
        <div className="mt-5 flex items-center gap-3">
          <h3 className="text-2xl font-bold tracking-tight text-graphite-800 md:text-[28px]">
            {title}
          </h3>
          {status && <StatusBadge status={status} />}
        </div>
        <p className="mt-4 text-[17px] leading-relaxed text-muted">{desc}</p>
        <ul className="mt-6 flex flex-col gap-3">
          {bullets.map((b, j) => (
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
      </Reveal>

      <Reveal delay={1} className={reversed ? "lg:order-1" : ""}>
        {visual}
      </Reveal>
    </div>
  );
}
