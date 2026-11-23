# BookRate Task 01 — Monorepo & Supabase Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Bun + Turborepo monorepo foundation with shared TypeScript config,
Biome tooling, and client-safe Supabase environment documentation — no backend app,
no placeholder packages, and no external product dependencies.

**Architecture:** Hosted Supabase (Postgres, Auth, Storage, RLS) is the backend; the
Next.js web app (MVP) consumes it directly, and Expo mobile is deferred to the phase
after MVP. Task 1 scaffolds tooling and structure only.

**Tech Stack:** Bun 1.4.0, Node 22.22.1, TypeScript, Biome. Turborepo 2.10.12 is the
currently installed environment version, not a project dependency pin or a verified
project version; the local dependency is resolved at BUILD.

**Spec:** `docs/superpowers/specs/task-01-backend-project-setup.md`

## Global Constraints

- Runtime: WSL2 Ubuntu. Use `/usr/bin/node` v22.22.1 and `~/.bun/bin/bun` 1.4.0. Do not
  use Windows Node v24.18.0 or Windows npm.
- No Docker, Deno, or Supabase CLI.
- No `@supabase/supabase-js`, `zod`, Drizzle, Next.js, Expo, or test frameworks.
- No `apps/api` or standalone backend.
- Only `packages/config`; do not create types/validators/supabase packages.
- Preserve `docs/PRD.md` byte-for-byte (UTF-8, CRLF). Never normalize line endings.
- `docs/ROADMAP.md` was restructured to the approved 30-day calendar plan during the
  documentation revision; Task 7 verifies strikethrough retention of the original Open
  Decision text and CRLF preservation.
- `README.md` exists; read it before editing, retain `# bookrate`, make additive changes
  only, never overwrite.
- Preserve all pre-existing working-tree changes; do not reset, stash, or revert.
- No commits at any point.
- Verification uses `grep` (ripgrep is not installed). A no-match search prints nothing
  and exits 1; that exit code is the expected success signal.
- Server-only secrets (`SUPABASE_SECRET_KEY`, `DATABASE_URL`) never enter `.env.example`
  or any client-facing file.

---

### Task 1: Root Workspace and Tooling

**Files:**
- Create: `package.json`, `turbo.json`, `.bun-version`, `.nvmrc`, `.gitignore`,
  `scripts/dev-placeholder.ts`

**Interfaces:**
- Produces: root scripts `build`, `typecheck`, `lint`, `format`, `format:check`, `dev`.
- Produces: workspace globs `apps/*`, `packages/*`.

- [ ] **Step 1: Create `package.json`**

```json
{
  "name": "bookrate",
  "private": true,
  "version": "0.0.0",
  "packageManager": "bun@1.4.0",
  "engines": { "node": ">=22.22.1" },
  "workspaces": ["apps/*", "packages/*"],
  "scripts": {
    "build": "turbo run build",
    "typecheck": "turbo run typecheck",
    "lint": "biome check .",
    "format": "biome format --write .",
    "format:check": "biome format .",
    "dev": "bun run scripts/dev-placeholder.ts"
  },
  "devDependencies": {
    "@biomejs/biome": "^2.0.0",
    "turbo": "^2.10.12",
    "typescript": "^5.0.0"
  }
}
```

- [ ] **Step 2: Create `turbo.json`**

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": { "dependsOn": ["^build"], "outputs": [] },
    "typecheck": { "dependsOn": ["^typecheck"], "outputs": [] },
    "dev": { "cache": false, "persistent": true }
  }
}
```

- [ ] **Step 3: Create version files**

`.bun-version`:

```
1.4.0
```

`.nvmrc`:

```
22.22.1
```

- [ ] **Step 4: Create `.gitignore`**

```
node_modules/
.turbo/
dist/
coverage/
*.tsbuildinfo
.env
.env.*
!.env.example
.next/
.expo/
```

- [ ] **Step 5: Create `scripts/dev-placeholder.ts`**

This file is planned for BUILD; it does not exist and is untested during planning.

```ts
console.log('BookRate dev: no applications are scaffolded yet.')
console.log('Web (Task 12/13) and mobile (Task 12/14) will provide dev servers.')
process.exit(0)
```

- [ ] **Step 6: Install tooling and record versions**

Run: `bun install`
Expected: lockfile created; three devDependencies resolved.

Run: `bun pm ls`
Expected: resolved versions listed. Record them as a BUILD-time verification decision.
Do not pin by assumption; replace caret ranges with exact versions only after confirming
the resolved values.

Run: `bunx turbo --version`
Expected: the turbo version matches the resolved value recorded from `bun pm ls`.

- [ ] **Step 7: Verify the dev placeholder**

Run: `bun run dev`
Expected: prints the two placeholder lines, then exits 0.

Run: `bun run dev; echo "exit=$?"`
Expected: `exit=0`.

- [ ] **Step 8: Verify working-tree preservation**

Run: `git status --short`
Expected: pre-existing `docs/PRD.md` and `docs/ROADMAP.md` modifications remain; no
reverts or resets performed.

---

### Task 2: Shared TypeScript Configuration

**Files:**
- Create: `packages/config/package.json`, `packages/config/tsconfig.base.json`,
  `packages/config/README.md`, `tsconfig.base.json`

**Interfaces:**
- Produces: `@bookrate/config` exposing `tsconfig.base.json`.
- Produces: a `typecheck` script so the Turbo task graph has a real target.

- [ ] **Step 1: Create `packages/config/package.json`**

```json
{
  "name": "@bookrate/config",
  "version": "0.0.0",
  "private": true,
  "files": ["tsconfig.base.json"],
  "scripts": {
    "typecheck": "tsc -p tsconfig.base.json --noEmit"
  }
}
```

- [ ] **Step 2: Create `packages/config/tsconfig.base.json`**

```json
{
  "$schema": "https://json.schemastore.org/tsconfig",
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noEmit": true,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true,
    "isolatedModules": true,
    "verbatimModuleSyntax": true
  },
  "files": []
}
```

- [ ] **Step 3: Create root `tsconfig.base.json`**

```json
{
  "extends": "./packages/config/tsconfig.base.json"
}
```

- [ ] **Step 4: Create `packages/config/README.md`**

```markdown
# @bookrate/config

Shared TypeScript configuration for the BookRate monorepo. Consuming packages extend
`../../packages/config/tsconfig.base.json`. Additional shared packages are introduced
only when a concrete consumer needs them.
```

- [ ] **Step 5: Verify**

Run: `bun --cwd packages/config run typecheck`
Expected: exit 0.

---

### Task 3: Biome Lint and Format

**Files:**
- Create: `biome.json`

**Interfaces:**
- Produces: lint/format rules for TS/JSON; Markdown excluded so docs remain untouched.

- [ ] **Step 1: Create `biome.json`**

```json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "vcs": { "enabled": true, "clientKind": "git", "useIgnoreFile": true },
  "files": { "includes": ["**/*.ts", "**/*.tsx", "**/*.json"] },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "javascript": {
    "formatter": { "quoteStyle": "single", "semicolons": "asNeeded" }
  }
}
```

- [ ] **Step 2: Verify config and Markdown exclusion**

Run: `bunx biome --version`
Expected: 2.x.

Run: `bunx biome check .`
Expected: exit 0; no `docs/*.md` processed.

If the schema URL or the `files.includes` key is rejected by the installed Biome
version, run `bunx biome init`, adopt the generated configuration, and re-run the
checks.

---

### Task 4: Reserve App Directories

**Files:**
- Create: `apps/web/.gitkeep`, `apps/mobile/.gitkeep`, `apps/README.md`

**Interfaces:**
- Produces: reserved directories with no `package.json` and no frameworks.

- [ ] **Step 1: Create reserved directories and notes**

`apps/web/.gitkeep` and `apps/mobile/.gitkeep` are empty files.

`apps/README.md`:

```markdown
# Apps

- `web/` — reserved for the Next.js web app (Task 12/13). No scaffold yet.
- `mobile/` — reserved for the Expo app (Task 12/14). No scaffold yet.
```

- [ ] **Step 2: Verify no app packages exist**

Run: `find apps -name package.json`
Expected: no output.

---

### Task 5: Client-Safe Environment Example

**Files:**
- Create: `.env.example`

**Interfaces:**
- Produces: documented client-safe variable names only; no secrets.

- [ ] **Step 1: Create `.env.example`**

```
# Web (Next.js)
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=

# Mobile (Expo)
EXPO_PUBLIC_SUPABASE_URL=
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
```

- [ ] **Step 2: Verify no server secrets in the example**

Run: `grep -nE "SERVICE_ROLE|SECRET_KEY|DATABASE_URL|ANON_KEY" .env.example`
Expected: no output; exit code 1 (grep no-match).

- [ ] **Step 3: Verify ignore rules**

Run: `git check-ignore -v .env`
Expected: matches the `.env` rule.

Run: `git check-ignore .env.example`
Expected: no output (example is tracked).

---

### Task 6: Extend README and Add Architecture Decision Record

**Files:**
- Modify: `README.md` (additive; preserve existing `# bookrate` heading)
- Create: `docs/architecture/0001-supabase-first-backend.md`

**Interfaces:**
- Produces: onboarding documentation and the accepted architecture record.

- [ ] **Step 1: Read current README and record state**

Run: `git show HEAD:README.md`
Run: `wc -c README.md`
Expected: 10 bytes; content is `# bookrate` with no trailing newline.

Confirm the heading is preserved; do not overwrite the file.

- [ ] **Step 2: Append documentation after the existing heading**

Read the current file, keep its existing content, and append the sections below.
Do not replace the file wholesale. Resulting content:

```markdown
# bookrate

Social Reading Platform — Supabase-first foundation.

## Status

Task 1 (monorepo & Supabase foundation) in setup. No application code yet.

## Stack

- Supabase (hosted PostgreSQL, Auth, Storage, RLS)
- Next.js (web, Vercel) and Expo (mobile) — deferred to later tasks
- Bun + Turborepo, TypeScript, Biome

## Repository Layout

- `apps/web`, `apps/mobile` — reserved
- `packages/config` — shared TypeScript config
- `docs/` — PRD, roadmap, architecture, Superpowers specs/plans

## Commands

- `bun install`
- `bun run typecheck`
- `bun run lint`
- `bun run format`
- `bun run build`
- `bun run dev`

## Environment

Use `.env.example` as the reference template for client-safe variable names. Per-app env
files (`apps/web/.env.local`, `apps/mobile/.env`) arrive with the apps in Task 12/13.
Never commit real values. Server-only secrets are deferred and never exposed to clients.

## Security

RLS policies, least privilege, parameterized database access, input validation, session
handling, and rate limiting remain application responsibilities. No user data is exposed
to publishable-key clients before default-deny RLS policies and negative authorization
tests exist.
```

- [ ] **Step 3: Write ADR `0001-supabase-first-backend.md`**

Include: context; decision (Supabase Postgres/Auth/Storage/RLS; Next.js on Vercel; Expo
mobile deferred to the phase after MVP; direct Supabase JS usage; custom API deferred for
MVP as a scope adjustment vs the PRD's separate-logical-API requirement); consequences;
explicit security
responsibilities; the RLS exposure gate (no user data reaches publishable-key clients
before default-deny policies and negative authorization tests exist); custom-API trigger
criteria (client-held secrets, multi-step transactions, feed fan-out, rate-limited
external calls, push orchestration); and rejected alternatives (standalone API;
Edge Functions/Deno).

- [ ] **Step 4: Verify README change is additive**

Run: `head -n 1 README.md`
Expected: `# bookrate`.

Run: `git diff -- README.md`
Expected: only additions; the heading is not deleted.

- [ ] **Step 5: Verify no legacy key naming in docs**

Run: `grep -RIn "ANON_KEY" README.md docs/architecture`
Expected: no output; exit code 1.

Run: `bunx biome check .`
Expected: exit 0.

---

### Task 7: ROADMAP Reconciliation Verification (30-day restructure, CRLF-preserving)

**Files:**
- Verify only: `docs/ROADMAP.md` was restructured during the approved documentation revision.
- Preserve: `docs/PRD.md` and existing working-tree state.

**Interfaces:**
- Consumes: approved 30-calendar-day ROADMAP restructure; PRD untouched.

The restructure keeps the two original Open Decisions bullets resolved in place with
strikethrough (original text retained). No byte-level mutation is performed in Task 1.

- [ ] **Step 1: Capture baseline**

Run: `sha256sum docs/PRD.md`
Run: `file docs/ROADMAP.md`
Expected: `CRLF line terminators`.

- [ ] **Step 2: Verify the approved restructure is present**

Run: `grep -n "30 hari kalender" docs/ROADMAP.md`
Expected: matches present (Target Rilis / Rencana 30 Hari Kalender).

Run: `grep -n "penyesuaian scope" docs/ROADMAP.md`
Expected: matches present (backend-decision section and Open Decisions).

Run: `grep -nF "~~Pilihan dan bentuk backend final.~~" docs/ROADMAP.md`
Expected: exactly one match; original text retained under strikethrough.

Run: `grep -n "Monorepo & Supabase Foundation (Task 01)" docs/ROADMAP.md`
Expected: match present in the 30-day task table.

Run: `grep -nE "Task 11|69–104|Backend Quality Gate|API route, validation" docs/ROADMAP.md`
Expected: no output; exit code 1 (legacy backend-first content removed).

- [ ] **Step 3: Verify preservation**

Run: `sha256sum docs/PRD.md`
Expected: identical to Step 1.

Run: `file docs/ROADMAP.md`
Expected: still `CRLF line terminators`.

Run: `git diff --ignore-space-at-eol -- docs/ROADMAP.md`
Expected: only the approved restructured content.

---

### Task 8: Full Toolchain Verification

**Files:**
- Verify only; no new files.

**Interfaces:**
- Consumes: all prior tasks.

- [ ] **Step 1: Workspace install**

Run: `bun install --frozen-lockfile`
Expected: exit 0.

- [ ] **Step 2: Typecheck**

Run: `bun run typecheck`
Expected: exit 0.

- [ ] **Step 3: Lint and format**

Run: `bun run lint`
Expected: exit 0.

Run: `bun run format:check`
Expected: exit 0.

- [ ] **Step 4: Build**

Run: `bun run build`
Expected: exit 0 (no-op-safe).

- [ ] **Step 5: Dev placeholder**

Run: `bun run dev`
Expected: prints the placeholder messages and exits 0.

- [ ] **Step 6: Forbidden-artifact audit**

Run: `find packages -maxdepth 1 -mindepth 1 -type d`
Expected: only `packages/config`.

Run: `find . -path ./node_modules -prune -o -name 'deno.json' -print`
Expected: no output.

Run: `grep -RInE '"(@supabase/supabase-js|zod|drizzle-orm|drizzle-kit|next|expo|react-native)"' package.json packages`
Expected: no output; exit code 1.

Run: `grep -nE "ANON_KEY|SERVICE_ROLE|SECRET_KEY|DATABASE_URL" .env.example`
Expected: no output; exit code 1.

- [ ] **Step 7: Final status review (no commit)**

Run: `git status --short`
Expected: only intended Task 1 files plus the pre-existing PRD/ROADMAP modifications.

Run: `git diff --stat`
Expected: no unexpected deletions or rewrites.

## Self-Review

- Spec coverage: tooling → Tasks 1–3; reserved apps → Task 4; env safety → Task 5;
  README/ADR → Task 6; ROADMAP → Task 7; verification → Task 8.
- Dev placeholder is planned in Task 1 and re-verified in Task 8 (message + exit 0);
  the script does not exist before BUILD and its behavior is an expectation, not a
  tested result.
- No placeholder packages: only `packages/config`.
- No placeholder text; all file contents provided.
- Naming consistency: publishable key used everywhere; no `ANON_KEY`.
- Server secrets documented nowhere in client env.
- README treated as existing: read first, heading preserved, additive edits only.
- Verification uses `grep` with explicit no-match exit code 1.
- Markdown code fences balanced; every opened block is closed.
- No commits; installation and implementation gated behind explicit BUILD approval.
