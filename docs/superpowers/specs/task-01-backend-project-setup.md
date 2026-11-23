# Task 01 — Backend Project Setup (Supabase-First Monorepo Foundation)

**Status:** Proposed — awaiting approval
**Date:** 2026-11-03
**Version:** 5.2

## 1. Objective

Establish the BookRate monorepo foundation for web (MVP), with mobile reserved for the
phase after MVP, and shared configuration on a Supabase-first backend. Task 1 delivers
structure, tooling, and documentation only.

Out of scope: standalone API, `apps/api`, `Bun.serve` stub, Hono/Elysia/Express/Fastify,
Docker, Deno, Supabase CLI, database schema, Auth flows, RLS policies, product features.

## 2. Current Repository Analysis

- OpenCode runs in WSL2 (Ubuntu), working dir `/mnt/c/Users/Lenovo/project/bookrate`.
- Actual WSL toolchain: Bun 1.4.0, Node v22.22.1, npm 11.16.0 (Windows interop path),
  Turborepo 2.10.12, git 2.53.0. These are the currently installed environment versions,
  not dependency pins or verified project versions. Deno, Supabase CLI, and Docker are
  unavailable.
- Windows Node v24.18.0 is reachable but is not the project runtime.
- Tracked files: `README.md`, `docs/PRD.md`, `docs/ROADMAP.md`.
- History: `169a559` initial commit; `0972869` PRD and roadmap.
- `README.md` already exists and is tracked: single line `# bookrate`, 10 bytes, no
  trailing newline. It is modified, not created.
- `docs/superpowers/specs/` and `docs/superpowers/plans/` contain the Task 01 spec and
  implementation plan (this document and its companion plan).
- `docs/PRD.md` and `docs/ROADMAP.md` have pre-existing uncommitted CRLF line-ending
  changes (HEAD is LF). Preserve the working-tree state; do not normalize or revert.

## 3. Architecture Decisions

1. **Supabase-first backend.** Hosted PostgreSQL, Supabase Auth, Storage (when needed),
   and RLS are the backend foundation.
2. **Clients:** Next.js web on Vercel (MVP); Expo + React Native mobile deferred to the
   phase after MVP. Both use the Supabase JS client with the publishable key, constrained
   by RLS.
3. **Custom API deferred** until a concrete requirement justifies it; the MVP deviation
   from the PRD's separate-logical-API requirement is recorded as an open decision in
   `docs/ROADMAP.md`, not as an equivalence.
4. **No Docker, no Deno, no Supabase CLI** in Task 1 or its workflow.
5. **Database workflow:** committed SQL migration files applied manually through the
   Supabase Dashboard SQL Editor. Migration directory and naming are an open decision
   for Task 2; nothing is assumed or created in Task 1.
6. **Type generation:** deferred until the schema exists; avoid hand-maintaining a large
   DB type definition. Propose a CLI-free option when relevant.
7. **Monorepo:** Bun workspaces + Turborepo. Lint/format via Biome.
8. **Minimal packages:** keep only `packages/config` (shared TypeScript base). Defer
   `packages/types`, `packages/validators`, and `packages/supabase` until concrete
   consumers exist; empty placeholder contracts would be premature abstraction.
9. **Apps:** reserve `apps/web` and `apps/mobile` directories only. No Next.js or Expo
   scaffolds in Task 1.
10. **Task 1 is tooling-only.** No `@supabase/supabase-js`, `zod`, or Drizzle.
11. **RLS exposure gate:** no table, view, or RPC containing user data is exposed to
    publishable-key clients until default-deny RLS policies and negative authorization
    tests exist. Secret-key access is limited to trusted server/admin contexts.
12. **Testing and CI:** deferred.

## 4. Reconciliation with PRD and ROADMAP

- `docs/PRD.md`: preserve byte-for-byte, including CRLF line endings.
- `docs/ROADMAP.md`: restructured to the approved 30-calendar-day MVP plan (CRLF
  preserved). The two original Open Decisions bullets stay resolved in place with
  strikethrough (original text retained), with new bullets appended:
  - Restructure phases into the 30-day MVP plan (Tasks 1–9 + buffer), with MVP vs
    deferred scope tables and the calendar-day capacity note (±20 working days as an
    assumption, not a certainty).
  - Rename Task 1 to "Monorepo & Supabase Foundation (Task 01)".
  - Mark backend-form decision resolved for MVP: Supabase-first; custom API deferred.
  - Mark hosting partially resolved: Web = Next.js on Vercel; Mobile = Expo (phase after
    MVP).
  - Add: DB migrations via committed SQL applied through the Dashboard SQL Editor.
  - Add: DB type generation deferred until the schema exists.
  - Add: scope-adjustment note vs PRD §5, keyless Google Books quota risk, ordered
    cut-list, and the agreed legacy task-numbering note.
- PRD requirement mapping (recorded, not rewritten):
  - "Backend API terpisah secara logis" (PRD §5): the MVP decision is Supabase direct from
    the web client with RLS. This is recorded as a **scope adjustment**, explicitly **not**
    a full satisfaction of the separate-API requirement (centralized validation,
    authorization, rate limiting, versioning), and remains an Open Decision for post-MVP
    review in `docs/ROADMAP.md`.
  - "Authentication middleware" → Supabase Auth establishes identity; authorization
    remains RLS policies plus explicit application-level business rules.
  - RLS exposure gate → user-data access stays closed to publishable-key clients until
    default-deny policies and negative authorization tests exist.
  - SQL-injection protection, input validation, session handling, and rate limiting are
    **application responsibilities**, not automatic Supabase features.

## 5. Final Folder Structure

```
bookrate/
├── apps/
│   ├── web/.gitkeep          # reserved; no Next.js scaffold
│   └── mobile/.gitkeep       # reserved; no Expo scaffold
├── packages/
│   └── config/               # shared tsconfig base only
├── docs/
│   ├── PRD.md                # preserved byte-for-byte, CRLF
│   ├── ROADMAP.md            # in-place resolution, CRLF
│   ├── architecture/0001-supabase-first-backend.md
│   └── superpowers/{specs,plans}/task-01-backend-project-setup.md
├── package.json
├── turbo.json
├── tsconfig.base.json
├── biome.json
├── .bun-version
├── .nvmrc
├── .env.example
├── .gitignore
└── README.md                 # existing; extended additively
```

## 6. Technology and Dependencies

**Installed in Task 1 (root devDependencies):** `turbo`, `typescript`, `@biomejs/biome`.
**Not installed:** `@supabase/supabase-js`, `zod`, `drizzle-orm`, `drizzle-kit`, Next.js,
React, Expo, React Native, test frameworks, CI tooling, Docker, Deno, Supabase CLI.

Exact dependency versions are not asserted in planning. During BUILD, resolved versions
are read from the lockfile (`bun pm ls`); pinning is a BUILD-time verification decision,
not an assumption.

## 7. Implementation Steps

1. Root workspace manifest and tooling, including the explicit `dev` placeholder.
2. Shared TypeScript base config in `packages/config`.
3. Biome configuration and scripts.
4. Reserve `apps/web` and `apps/mobile`.
5. Client-safe environment example.
6. Minimally extend the existing `README.md` (preserve `# bookrate`) and add the
   architecture decision record.
7. ROADMAP reconciliation: verify the approved 30-day restructure (strikethrough
   resolution retained; original Open Decision text retained; CRLF preserved).
8. Full toolchain verification (no commits).

## 8. Files to Create or Modify

Create: `package.json`, `turbo.json`, `tsconfig.base.json`, `biome.json`, `.bun-version`,
`.nvmrc`, `.env.example`, `.gitignore`, `scripts/dev-placeholder.ts`,
`apps/web/.gitkeep`, `apps/mobile/.gitkeep`, `apps/README.md`,
`packages/config/{package.json,tsconfig.base.json,README.md}`,
`docs/architecture/0001-supabase-first-backend.md`.

Present (created during planning): `docs/superpowers/specs/task-01-backend-project-setup.md`,
`docs/superpowers/plans/task-01-backend-project-setup.md`.

Modify: `README.md` — read first, preserve the existing `# bookrate` heading, append
documentation only (no blind overwrite). `docs/ROADMAP.md` — restructured to the
approved 30-day MVP plan; Open Decisions resolved in place with strikethrough (original
text retained); CRLF-preserving.

Preserve unchanged: `docs/PRD.md` and all pre-existing working-tree state.

## 9. Environment Variables

Client-safe only in `.env.example`:

```
# Web (Next.js)
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=

# Mobile (Expo)
EXPO_PUBLIC_SUPABASE_URL=
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
```

**Trusted server-only secrets (documented separately, not in `.env.example`, deferred
until a server context exists):**

- `SUPABASE_SECRET_KEY` — replaces the legacy service_role key. Never prefix with
  `NEXT_PUBLIC_` or `EXPO_PUBLIC_`; never ship in client bundles.
- `DATABASE_URL` — direct database access for migrations/admin tooling only.

Local `.env` is git-ignored. `.env.example` contains no secrets. Root `.env.example`
is a reference template only; per-app env files (`apps/web/.env.local`,
`apps/mobile/.env`) are introduced with the apps in Task 12/13.

## 10. Development Commands

- `bun run typecheck` → Turbo → `packages/config` typecheck
- `bun run lint` → `biome check .`
- `bun run format` → `biome format --write .`
- `bun run format:check` → `biome format .`
- `bun run build` → Turbo (no-op-safe until apps exist)
- `bun run dev` → `bun run scripts/dev-placeholder.ts`; prints a clear "no applications
  are scaffolded yet" message and exits 0 until Task 12/13

`scripts/dev-placeholder.ts` is planned for creation during BUILD. It does not exist and
has not been tested during planning; the message and exit-0 behavior above are planned
expectations.

## 11. Security Model (corrected)

Supabase is not an automatic security solution. Task 1 records these requirements:

- **RLS policies** must be written for every exposed table/schema; default deny.
- **RLS exposure gate:** no table, view, or RPC containing user data is exposed to
  publishable-key clients until default-deny RLS policies and negative authorization
  tests exist. Secret-key access is limited to trusted server/admin contexts.
- **Least privilege:** clients use only the publishable key. Secret/server keys are
  restricted to trusted server contexts and deferred until required.
- **SQL injection:** use Supabase/PostgREST parameterized query APIs; never concatenate
  user input into SQL. RLS is authorization, not injection protection.
- **Input validation:** must be implemented at application boundaries (later via Zod or
  equivalent); database constraints are defense-in-depth, not a substitute.
- **Authorization:** RLS enforces row-level access; business-rule authorization must be
  explicit in application logic or database functions.
- **Session handling:** Supabase Auth issues sessions, but the app must store and refresh
  them securely (secure cookies for web SSR, secure storage on mobile) and never log tokens.
- **Rate limiting:** not automatic; design and enforce limits where appropriate.
- **Secrets:** `.env` ignored; server-only secrets separated; no secrets in docs or code.

## 12. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| No Supabase CLI | Committed SQL applied via Dashboard SQL Editor; revisit tooling later |
| Migration location undefined | Open decision for Task 2: choose `db/migrations/` or `supabase/migrations/` before creating files |
| DB type drift | Defer generation; choose CLI-free option once schema exists |
| Gate restructure vs foundation | Reserve app dirs only; no Next.js/Expo scaffolds |
| RLS as sole authority | Explicit RLS policy testing at the hardening gate (ROADMAP Task 8); app-level rules documented |
| Premature abstractions | Only `packages/config`; other packages deferred |
| Secret leakage | Client-safe env example; server-only secrets documented separately |
| PRD/ROADMAP line-ending drift | Preserve line endings; verify CRLF and PRD hash (ROADMAP restructure done in documentation revision, not BUILD) |
| README blind overwrite | Read first; preserve heading; additive edits only |
| Version drift | Pin from lockfile; `.bun-version`/`.nvmrc` |
| Windows npm interop | Use Bun exclusively from WSL |

## 13. Testing Strategy

No test framework in Task 1 (deferred). Verification is toolchain health: workspace
resolution, `tsc --noEmit`, Biome lint/format, and build command success.

## 14. Acceptance Criteria

- `bun install` resolves the workspace.
- `bun run typecheck`, `bun run lint`, `bun run format:check`, `bun run build` pass.
- `bun run dev` prints the placeholder message and exits 0.
- `apps/web` and `apps/mobile` exist as reserved dirs with no frameworks.
- Only `packages/config` exists; no placeholder contract packages.
- `.env.example` contains only client-safe URL + publishable-key variables.
- No server secrets, `apps/api`, backend framework, Docker, Deno, or Supabase CLI.
- `README.md` remains present with its original `# bookrate` heading; changes are
  additive, not a blind overwrite.
- PRD unchanged byte-for-byte; ROADMAP restructured to the approved 30-day MVP plan with
  Open Decisions resolved in place (strikethrough, original text retained) and CRLF
  preserved.
- Spec and plan documents exist; no commits made.
