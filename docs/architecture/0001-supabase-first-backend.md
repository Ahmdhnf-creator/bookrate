# ADR 0001: Supabase-First Backend for the MVP

- Status: Accepted — **partially amended by ADR 0002** (2026-11-15): database access
  from the web server now goes through Prisma Client, and schema management becomes a
  hybrid of Prisma Migrate + committed SQL. Supabase Auth, the RLS Exposure Gate, the
  custom-API deferral/trigger criteria, and all tool prohibitions remain unchanged.
  See `docs/architecture/0002-prisma-orm-backend.md`.
- Date: 2026-11-06
- Related: `docs/ROADMAP.md` — "Keputusan Backend MVP dan Penyesuaian Terhadap PRD"

## Context

The PRD requires the backend API to be logically separate from the UI. BookRate is a
web-first project: the web MVP is the primary priority, and mobile development is
pending until the web MVP is finished and time allows. The MVP needs authentication,
data storage, and authorization without the cost of building and operating a separate
API server during the setup phase.

## Decision

- **Supabase** (hosted PostgreSQL, Auth, Storage, RLS) is the backend foundation.
- **Next.js on Vercel** is the web application target; the web MVP is the priority.
- **Expo mobile is deferred** to the phase after the MVP; it must not block web MVP
  progress.
- The web client uses the **Supabase JS client directly** (Auth + Postgres) with
  **RLS as the authorization layer**.
- A **custom API is deferred for the MVP**. This is a recorded **scope adjustment**
  against the PRD's separate-logical-API requirement — it does not fully satisfy that
  requirement; it is not a claim that the requirement is met.
- Database management for the MVP is **Dashboard-first**: plain SQL files committed to
  the repository are the schema source of truth and are run manually through the
  Supabase Dashboard SQL Editor, with application status recorded in
  `db/SCHEMA_STATE.md`. There is **no Supabase CLI, no Docker, no local Supabase
  instance, and no Edge Functions** for the MVP. See also the Rejected Alternatives
  below and the ROADMAP Open Decision that this resolves.

## Consequences

- Fast MVP setup and low operational overhead; no API server to deploy or maintain yet.
- Security and authorization correctness depend on RLS policies and tests rather than
  application-layer checks.
- Features that need server-held secrets, complex transactions, or fan-out must wait
  for, or trigger, the custom-API phase.
- The mobile app reuses the same Supabase project later without backend rework.
- The deferred custom API remains an open decision after the MVP.

## Security Responsibilities

RLS policies, least privilege, parameterized database access, input validation, session
handling, and rate limiting are explicit application responsibilities. They must be
implemented and reviewed as part of feature work, not assumed from Supabase defaults.

## RLS Exposure Gate

No user data reaches publishable-key clients before default-deny RLS policies and
negative authorization tests exist. Until that gate passes, data must not be exposed to
browser clients that hold only publishable credentials.

## Custom-API Trigger Criteria

The custom API phase is triggered when any of the following become necessary:

- Client-held secrets (anything that must not ship in the browser bundle).
- Multi-step transactions that cannot be expressed as a single RLS-guarded operation.
- Feed fan-out or aggregation that is impractical client-side.
- Rate-limited external calls that must be enforced server-side.
- Push notification orchestration.

## Rejected Alternatives

- **Standalone custom API for the MVP:** rejected for the MVP to keep setup time and
  operations minimal; reconsidered via the trigger criteria above.
- **Edge Functions / Deno:** rejected for the MVP for the same scope reasons; adds a
  second server-side surface before the plain Supabase client path is proven.
