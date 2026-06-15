export function Logo({ dark = false }: { dark?: boolean }) {
  return (
    <div className="flex items-center gap-2.5">
      <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-[#1C1C2E] to-[#0F0F18] text-[18px] font-bold text-white">
        D
      </span>
      <span
        className={`text-xl font-bold ${dark ? "text-graphite-900" : "text-white"}`}
      >
        Dispax
      </span>
    </div>
  );
}
