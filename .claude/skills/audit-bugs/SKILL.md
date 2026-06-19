---
name: audit-bugs
description: Audit the Dispax backend for functional bugs, inconsistencies, SOLID/architecture violations, and security gaps, then append the verified findings as a checklist to docs/audit-tasks.md (deduplicated against what is already there). Use when asked to find bugs in the project, run a bug audit, or update the audit task list.
---

# Audit Bugs → docs/audit-tasks.md

Find real bugs in the Dispax codebase and record them as actionable checklist items in
`docs/audit-tasks.md`, **without** duplicating findings that are already listed.

This is the Dispax project: Scala 3 + ZIO 2 + ZIO-HTTP (Tapir) + Doobie + PostgreSQL.
Modules: `core auth ride driver schedule notification billing api` (+ `web` Flutter).
Read `CLAUDE.md` first for architecture, invariants, and business rules.

## Guiding principle

**Only record VERIFIED findings.** Read the actual code at each suspected location before
writing it down. Drop anything you cannot confirm, and correct severities you cannot justify.
A wrong "HIGH" wastes the reader's time more than a missed "LOW". Do not report stylistic
preferences — only real bugs, gaps, inconsistencies, and vulnerabilities.

## Step 1 — Read existing state (mandatory, for dedup)

1. Read `docs/audit-tasks.md` in full. Note every bug/finding already recorded — both the
   numbered direction sections (1–4) and any previously appended findings. Build a mental set
   of `(file:line, short-description)` already present.
2. Read `CLAUDE.md` (invariants, business rules) and skim `docs/requirements.md` so you can
   judge requirement gaps.

If `docs/audit-tasks.md` does not exist, create it with this header before appending:
```
# Задачи аудита проекта

Чеклист направлений аудита. Отмечай выполненные галочкой.

---
```

## Step 2 — Hunt for bugs (verify each before recording)

Cover these areas. For broad coverage, you may fan out up to 3 read-only explorer agents (one
per area cluster), but **you** verify each returned finding against the real code before
trusting it — agents over-report and mis-severity.

**A. Functional bugs**
- Stubs / unfinished work: `???`, `NotImplementedError`, TODO/FIXME/HACK in `*/src/main`
  (not tests). Mock services wired into production (e.g. `PaymentChecker`).
- Non-exhaustive `match` on enums (`RideStatus`, `PersonRole`, `InvoiceStatus`) — MatchError
  risk or a `case _` that silently mishandles.
- Ride status machine: illegal transitions; `canBeAssigned/Started/Completed/Cancelled` gaps.
- Logic bugs: inverted conditions, off-by-one in pagination, `Option.get` on None, bad
  `getOrElse` defaults, swallowed failures (`.ignore`/`.orElse` hiding real errors — note that
  `.orElse` is a failure-fallback, not a union).
- Money/time: BigDecimal rounding, Instant vs LocalDate/timezone confusion.
- Concurrency: missing atomic compare-and-set on assignment; shared mutable state.

**B. Security**
- Tenant isolation: repository `findById/update/delete` and endpoints that don't filter by
  `company_id`. (Confirmed-safe baseline: billing `update/delete/replaceItems/unlinkRides` DO
  filter by `taxi_company_id`. Note: one `PersonId` ⇒ one company, so self-data reads by
  `user.userId` are low-risk, not exploitable cross-tenant.)
- SQL injection: Doobie queries with string concatenation instead of `$param` (watch ORDER BY,
  LIMIT, dynamic filters).
- Authn/Authz: sensitive routes using `endpoint` instead of `secureEndpoint`; missing
  `checkRole`; admin/billing ops reachable by driver/client.
- Hardcoded secrets (dev seed `V1001` and test fixtures are OK).
- Error leakage: raw `exception.message`/stack traces in HTTP responses.
- Input validation: coordinates, prices, email, UUID, pagination bounds.

**C. SOLID / architecture**
- Business logic in HTTP handlers (`*/openapi/*.scala`) instead of the application layer.
- God-objects (oversized services/traits) and bloated traits (ISP).
- Untyped errors in the domain (`Task` + `RuntimeException` instead of `IO[XxxError, _]`).
- Layer leakage: domain objects returned directly as HTTP bodies instead of DTOs; DTOs in
  domain.
- Duplication: same trait/logic copied across modules (Validator, repository traits, DATEV CSV,
  `checkRole`/`requireCompanyId` helpers).

## Step 3 — Verify build & tests (context for the report)

Run and note results (don't block on them; they're context, not findings):
- `sbt compile` (or `sbt "Test/compile"`).
- `make test` — per-module unit + integration.

A finding is more credible if tests are green yet the bug exists (means it's untested).

## Step 4 — Append to docs/audit-tasks.md (deduplicated)

Append a dated subsection under the existing content (do not rewrite sections 1–4, do not
delete prior findings). Use this exact shape so it reads as a checklist:

```
## Найденные баги — <YYYY-MM-DD>

> Проверено по коду. Severity: HIGH / MEDIUM / LOW.

- [ ] **[HIGH] <короткое название>** — `<module>/.../File.scala:<line>` — <что именно не так и почему это баг>. _Категория: Functional|Security|SOLID._
- [ ] **[MEDIUM] ...**
- [ ] **[LOW] ...**
```

Rules:
- **Dedup:** before writing each item, check it is not already present in the file (same
  `file:line` or same described bug under sections 1–4 or a prior dated subsection). Skip
  duplicates. If a prior finding is now fixed, leave it (don't tick boxes for the user) but you
  may note "(возможно, исправлено)" only if you verified the code changed.
- One concrete, actionable item per line. Include the file and line so it's directly fixable.
- Order within the subsection: HIGH first, then MEDIUM, then LOW.
- If a run finds **no new** bugs beyond what's recorded, append the dated subsection with a
  single line: `- Новых багов не найдено (всё ранее записанное актуально).`

## Step 5 — Report back to the user

Summarize in chat: how many new findings by severity, how many duplicates skipped, build/test
status, and the path `docs/audit-tasks.md`. Do **not** fix the bugs — this skill only records
them. Offer to start a fix-flow for the HIGH items if the user wants.

Do not commit the file unless the user asks.
