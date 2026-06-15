import { ReactNode } from "react";

export function Container({
  children,
  className = "",
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={`mx-auto w-full max-w-7xl px-6 md:px-12 lg:px-[120px] ${className}`}>
      {children}
    </div>
  );
}
