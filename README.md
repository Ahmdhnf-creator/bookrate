# bookrate

Social Reading Platform — Supabase-first foundation.

## Status

Task 1 (monorepo & Supabase foundation) in setup. No application code yet.

## Stack

- Supabase (hosted PostgreSQL, Auth, Storage, RLS as the security boundary)
- Prisma ORM — Prisma Client (server-side only) + Prisma Migrate; committed SQL
  (`db/scripts/`) stays in charge of RLS, policies, grants, triggers, functions, views,
  and other PostgreSQL-specific objects (ADR 0002)
- Next.js (web, Vercel) and Expo (mobile) — deferred to later tasks; mobile talks to
  Supabase directly and never uses Prisma Client
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
handling, and rate limiting remain application responsibilities. Server-side database
access runs through Prisma Client with a per-transaction user identity context
(`SET LOCAL ROLE` + JWT claims, ADR 0002) — never with a superuser, `service_role`, or
`BYPASSRLS` connection. No user data is exposed
to publishable-key clients before default-deny RLS policies and negative authorization
tests exist.
