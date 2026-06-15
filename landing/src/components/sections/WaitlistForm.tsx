"use client";

import { FormEvent, useState } from "react";
import { useTranslations } from "next-intl";
import { Icons } from "../ui/icons";

type Status = "idle" | "sending" | "success" | "error";

export function WaitlistForm() {
  const t = useTranslations("cta");
  const [email, setEmail] = useState("");
  const [status, setStatus] = useState<Status>("idle");
  const [message, setMessage] = useState("");

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setStatus("error");
      setMessage(t("errorEmail"));
      return;
    }
    setStatus("sending");
    setMessage("");
    try {
      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email }),
      });
      if (!res.ok) throw new Error("request failed");
      setStatus("success");
      setMessage(t("success"));
      setEmail("");
    } catch {
      setStatus("error");
      setMessage(t("errorGeneric"));
    }
  }

  return (
    <div className="mt-9 w-full max-w-[520px]">
      <form onSubmit={onSubmit} className="flex flex-col gap-3 sm:flex-row">
        <input
          type="email"
          required
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder={t("placeholder")}
          aria-label="Email"
          className="flex-1 rounded-lg border border-white/[0.14] bg-white/[0.06] px-[18px] py-[15px] text-[15px] text-white placeholder:text-faint focus:border-accent focus:outline-none"
        />
        <button
          type="submit"
          disabled={status === "sending"}
          className="rounded-lg bg-accent px-6 py-[15px] text-[15px] font-semibold text-white transition-colors hover:bg-accent-dark disabled:opacity-60"
        >
          {status === "sending" ? t("sending") : t("submit")}
        </button>
      </form>

      <div className="mt-4 flex items-center justify-center gap-1.5">
        {status === "success" ? (
          <p className="text-[13px] font-medium text-accent-light">{message}</p>
        ) : status === "error" ? (
          <p className="text-[13px] font-medium text-[#FCA5A5]">{message}</p>
        ) : (
          <>
            <Icons.lock className="h-3.5 w-3.5 text-faint" />
            <span className="text-[13px] text-faint">{t("note")}</span>
          </>
        )}
      </div>
    </div>
  );
}
