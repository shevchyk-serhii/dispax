import { NextRequest, NextResponse } from "next/server";

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export async function POST(req: NextRequest) {
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid_body" }, { status: 400 });
  }

  const get = (key: string) =>
    typeof body === "object" && body !== null && key in body
      ? String((body as Record<string, unknown>)[key]).trim()
      : "";

  const name = get("name");
  const email = get("email");
  const company = get("company");
  const message = get("message");

  if (!EMAIL_RE.test(email)) {
    return NextResponse.json({ error: "invalid_email" }, { status: 400 });
  }
  if (!name || !message) {
    return NextResponse.json({ error: "missing_fields" }, { status: 400 });
  }

  // MVP: log the lead. Placeholder for future SMTP / CRM integration
  // (mirrors the waitlist route and the backend billing email stub).
  console.log(
    `[contact] ${name} <${email}>${company ? ` (${company})` : ""}: ${message}`,
  );

  return NextResponse.json({ ok: true }, { status: 200 });
}
