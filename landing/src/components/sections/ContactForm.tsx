"use client";

import { FormEvent, useState } from "react";
import { useTranslations } from "next-intl";
import { Icons } from "../ui/icons";

type Status = "idle" | "sending" | "success" | "error";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function ContactForm() {
  const t = useTranslations("kontakt.form");
  const [fields, setFields] = useState({
    name: "",
    email: "",
    company: "",
    message: "",
  });
  const [status, setStatus] = useState<Status>("idle");
  const [message, setMessage] = useState("");

  function set(key: keyof typeof fields, value: string) {
    setFields((f) => ({ ...f, [key]: value }));
  }

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!fields.name.trim() || !fields.message.trim()) {
      setStatus("error");
      setMessage(t("errorRequired"));
      return;
    }
    if (!EMAIL_RE.test(fields.email)) {
      setStatus("error");
      setMessage(t("errorEmail"));
      return;
    }
    setStatus("sending");
    setMessage("");
    try {
      const res = await fetch("/api/contact", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(fields),
      });
      if (!res.ok) throw new Error("request failed");
      setStatus("success");
      setMessage(t("success"));
      setFields({ name: "", email: "", company: "", message: "" });
    } catch {
      setStatus("error");
      setMessage(t("errorGeneric"));
    }
  }

  const inputClass =
    "w-full rounded-lg border border-line bg-surface px-4 py-3 text-[15px] text-ink placeholder:text-faint focus:border-accent focus:outline-none focus:ring-2 focus:ring-accent/20";

  return (
    <form onSubmit={onSubmit} className="flex flex-col gap-4">
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="flex flex-col gap-1.5">
          <span className="text-[13px] font-medium text-graphite-800">
            {t("nameLabel")}
          </span>
          <input
            type="text"
            required
            value={fields.name}
            onChange={(e) => set("name", e.target.value)}
            placeholder={t("namePlaceholder")}
            className={inputClass}
          />
        </label>
        <label className="flex flex-col gap-1.5">
          <span className="text-[13px] font-medium text-graphite-800">
            {t("emailLabel")}
          </span>
          <input
            type="email"
            required
            value={fields.email}
            onChange={(e) => set("email", e.target.value)}
            placeholder={t("emailPlaceholder")}
            className={inputClass}
          />
        </label>
      </div>

      <label className="flex flex-col gap-1.5">
        <span className="text-[13px] font-medium text-graphite-800">
          {t("companyLabel")}
        </span>
        <input
          type="text"
          value={fields.company}
          onChange={(e) => set("company", e.target.value)}
          placeholder={t("companyPlaceholder")}
          className={inputClass}
        />
      </label>

      <label className="flex flex-col gap-1.5">
        <span className="text-[13px] font-medium text-graphite-800">
          {t("messageLabel")}
        </span>
        <textarea
          required
          rows={5}
          value={fields.message}
          onChange={(e) => set("message", e.target.value)}
          placeholder={t("messagePlaceholder")}
          className={`${inputClass} resize-y`}
        />
      </label>

      <button
        type="submit"
        disabled={status === "sending"}
        className="rounded-lg bg-accent px-6 py-3.5 text-[15px] font-semibold text-white transition-colors hover:bg-accent-dark disabled:opacity-60"
      >
        {status === "sending" ? t("sending") : t("submit")}
      </button>

      <div className="flex items-center gap-1.5">
        {status === "success" ? (
          <p className="text-[13px] font-medium text-accent-dark">{message}</p>
        ) : status === "error" ? (
          <p className="text-[13px] font-medium text-[#DC2626]">{message}</p>
        ) : (
          <>
            <Icons.lock className="h-3.5 w-3.5 text-faint" />
            <span className="text-[13px] text-muted">{t("note")}</span>
          </>
        )}
      </div>
    </form>
  );
}
