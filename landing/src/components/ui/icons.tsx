import { SVGProps } from "react";

type IconProps = SVGProps<SVGSVGElement>;

function Base({ children, ...props }: IconProps & { children: React.ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      {...props}
    >
      {children}
    </svg>
  );
}

export const Icons = {
  clock: (p: IconProps) => (
    <Base {...p}>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7v5l3 2" />
    </Base>
  ),
  plane: (p: IconProps) => (
    <Base {...p}>
      <path d="M17.8 19.2 16 11l3.5-3.5a2.1 2.1 0 0 0-3-3L13 8 4.8 6.2a1 1 0 0 0-.9 1.7l5 3.1-2 2.9-2.6-.6a1 1 0 0 0-.9 1.6l2.4 2.4 2.4 2.4a1 1 0 0 0 1.6-.9l-.6-2.6 2.9-2 3.1 5a1 1 0 0 0 1.7-.9Z" />
    </Base>
  ),
  scatter: (p: IconProps) => (
    <Base {...p}>
      <circle cx="6" cy="7" r="1.5" />
      <circle cx="17" cy="6" r="1.5" />
      <circle cx="9" cy="14" r="1.5" />
      <circle cx="18" cy="16" r="1.5" />
      <circle cx="13" cy="10" r="1.5" />
    </Base>
  ),
  bellOff: (p: IconProps) => (
    <Base {...p}>
      <path d="M8.7 6.3A5 5 0 0 1 17 10c0 2.5.5 4 1.2 5" />
      <path d="M6 10c0 3-1 5-2 6h12.5" />
      <path d="M10.3 21a2 2 0 0 0 3.4 0" />
      <path d="m3 3 18 18" />
    </Base>
  ),
  dashboard: (p: IconProps) => (
    <Base {...p}>
      <rect x="3" y="3" width="7" height="9" rx="1" />
      <rect x="14" y="3" width="7" height="5" rx="1" />
      <rect x="14" y="12" width="7" height="9" rx="1" />
      <rect x="3" y="16" width="7" height="5" rx="1" />
    </Base>
  ),
  planeLand: (p: IconProps) => (
    <Base {...p}>
      <path d="M3.5 19h17" />
      <path d="M5 15.5 19 18a1.5 1.5 0 0 0 .8-2.9l-4.3-2-2.3-7.3a1 1 0 0 0-1.8-.2l-.4 4.8-4.2-1.2-1-2.3a.8.8 0 0 0-1.5.3l.4 3.6a2 2 0 0 0 1.5 1.8Z" />
    </Base>
  ),
  pin: (p: IconProps) => (
    <Base {...p}>
      <path d="M12 21s-6-5.2-6-10a6 6 0 0 1 12 0c0 4.8-6 10-6 10Z" />
      <circle cx="12" cy="11" r="2.2" />
    </Base>
  ),
  shield: (p: IconProps) => (
    <Base {...p}>
      <path d="M12 3 5 6v5c0 4.5 3 8 7 10 4-2 7-5.5 7-10V6Z" />
      <path d="m9.5 12 1.8 1.8 3.5-3.6" />
    </Base>
  ),
  chart: (p: IconProps) => (
    <Base {...p}>
      <path d="M4 4v16h16" />
      <rect x="8" y="11" width="3" height="6" rx="0.5" />
      <rect x="13.5" y="7" width="3" height="10" rx="0.5" />
    </Base>
  ),
  check: (p: IconProps) => (
    <Base {...p}>
      <circle cx="12" cy="12" r="9" />
      <path d="m8.5 12 2.4 2.4 4.6-4.8" />
    </Base>
  ),
  lock: (p: IconProps) => (
    <Base {...p}>
      <rect x="5" y="11" width="14" height="9" rx="2" />
      <path d="M8 11V8a4 4 0 0 1 8 0v3" />
    </Base>
  ),
  radar: (p: IconProps) => (
    <Base {...p}>
      <path d="M19.07 4.93a10 10 0 1 0 2.5 4.07" />
      <path d="M15.5 8.5a5 5 0 1 0 1.4 2.3" />
      <path d="M12 12 19 5" />
      <circle cx="12" cy="12" r="1" />
    </Base>
  ),
  receipt: (p: IconProps) => (
    <Base {...p}>
      <path d="M5 3.5 6.5 5 8 3.5 9.5 5 11 3.5 12.5 5 14 3.5 15.5 5 17 3.5 18.5 5 19 4.5V20.5L17 19l-1.5 1.5L14 19l-1.5 1.5L11 19l-1.5 1.5L8 19l-1.5 1.5L5 19.5Z" />
      <path d="M8 9h8" />
      <path d="M8 13h5" />
    </Base>
  ),
  layers: (p: IconProps) => (
    <Base {...p}>
      <path d="m12 3 9 5-9 5-9-5 9-5Z" />
      <path d="m3 13 9 5 9-5" />
    </Base>
  ),
  swap: (p: IconProps) => (
    <Base {...p}>
      <path d="M7 4 3 8l4 4" />
      <path d="M3 8h13a4 4 0 0 1 0 8h-1" />
      <path d="m17 20 4-4-4-4" />
      <path d="M21 16H8" />
    </Base>
  ),
  calendarCheck: (p: IconProps) => (
    <Base {...p}>
      <rect x="3.5" y="5" width="17" height="15" rx="2" />
      <path d="M3.5 9.5h17" />
      <path d="M8 3v3M16 3v3" />
      <path d="m9 14 2 2 4-4" />
    </Base>
  ),
  fileShield: (p: IconProps) => (
    <Base {...p}>
      <path d="M13 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h4" />
      <path d="M13 3v4a1 1 0 0 0 1 1h4" />
      <path d="M18 13.5 15 15v2.2c0 1.5 1.2 2.7 3 3.3 1.8-.6 3-1.8 3-3.3V15Z" />
    </Base>
  ),
};

export type IconName = keyof typeof Icons;
