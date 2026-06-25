"use client";

import { ReactNode, useEffect, useRef, useState } from "react";

const delays: Record<number, string> = {
  0: "",
  1: "delay-100",
  2: "delay-200",
  3: "delay-300",
  4: "delay-[400ms]",
  5: "delay-500",
};

/**
 * Reveals its children with a one-shot fade + rise as they scroll into view.
 * CSS-only (IntersectionObserver + Tailwind transitions) — no animation lib.
 * Honours prefers-reduced-motion: content is shown immediately, no transition.
 */
export function Reveal({
  children,
  delay = 0,
  as: Tag = "div",
  className = "",
}: {
  children: ReactNode;
  delay?: 0 | 1 | 2 | 3 | 4 | 5;
  as?: "div" | "section" | "li" | "span";
  className?: string;
}) {
  const ref = useRef<HTMLElement>(null);
  const [shown, setShown] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) {
          setShown(true);
          observer.disconnect();
        }
      },
      { threshold: 0.12, rootMargin: "0px 0px -10% 0px" },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <Tag
      ref={ref as never}
      className={`transition-all duration-700 ease-out motion-reduce:transition-none motion-reduce:translate-y-0 motion-reduce:opacity-100 ${
        shown ? "translate-y-0 opacity-100" : "translate-y-4 opacity-0"
      } ${delays[delay]} ${className}`}
    >
      {children}
    </Tag>
  );
}
