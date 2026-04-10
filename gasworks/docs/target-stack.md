# Gasworks Target Stack

This document defines the preferred technology stack for all rigs built using the gasworks
rapid-prototype workflow. When a PM writes a PRD or an Architect writes an architecture doc,
default to this stack unless there is a specific reason to deviate. Deviations should be
explicitly noted and justified in the architecture doc.

---

## Guiding Principles

- **Rapid iteration over perfect architecture** — this stack is optimized for going from idea
  to working prototype fast, not for enterprise scale
- **Shared mental model across projects** — same stack means context switches between rigs are
  cheap; learnings transfer directly
- **Minimize vendor count** — every new vendor is a new account, billing relationship, and
  migration risk
- **Infrastructure as code, always** — no manual portal clicks; every resource is reproducible
  from `tofu apply`

---

## The Stack

### Language

| Tool | Role |
|---|---|
| **TypeScript** | Required across all apps and packages. No plain JS. |

### Frontend — Web

| Tool | Role | Notes |
|---|---|---|
| **React** | UI framework | |
| **Vite** | Build tool | Or Next.js if SSR/SSG is needed |
| **Tailwind CSS** | Styling | Utility-first; no custom CSS unless unavoidable |
| **shadcn/ui** | Component library | Copy-paste components on top of Tailwind + Radix |

### Frontend — Mobile

| Tool | Role | Notes |
|---|---|---|
| **React Native** | Mobile UI framework | |
| **Expo** | Runtime + dev tooling | Managed workflow; no bare RN for prototypes |
| **Expo Router** | Navigation | File-based routing; consistent with web mental model |
| **NativeWind** | Styling | Tailwind for React Native; keeps web/mobile styling consistent |

### Monorepo

| Tool | Role | Notes |
|---|---|---|
| **pnpm workspaces** | Package management | Shared dependencies, workspace protocol |
| **Turborepo** | Build orchestration | Caching, task pipelines across packages |

Standard workspace layout:
```
apps/
  web/          — React/Vite or Next.js
  mobile/       — Expo React Native
packages/
  ui/           — shared shadcn/ui components (web)
  api/          — typed Supabase query functions
  types/        — shared TypeScript types
  config/       — shared ESLint, TypeScript, Tailwind configs
```

### Backend

| Tool | Role | Notes |
|---|---|---|
| **Supabase** (self-hosted on Azure) | Database, auth, storage, realtime, edge functions | Self-hosted eliminates free tier limits and project pausing |
| **PostgreSQL** | Database | Via Supabase; native RLS enforced at DB level |
| **Supabase Auth** | Authentication | Email/password, Google OAuth, Apple OAuth, magic links |
| **Supabase Realtime** | Live subscriptions | Channel-based; used for live data sync across clients |
| **Supabase Storage** | File storage | Images, attachments, user uploads |
| **Supabase Edge Functions** | Serverless compute | Deno-based; for webhooks, background logic, third-party integrations |

**Why self-hosted**: Supabase free tier pauses projects after 7 days of inactivity, has a 500 MB
database limit, and allows only 2 projects. Self-hosted on Azure (using existing $150/month
credits) eliminates all three constraints while keeping the same Supabase DX and SDKs.

### Hosting & Deployment

| Tool | Role | Notes |
|---|---|---|
| **Vercel** | Web hosting | Auto-deploys from GitHub; preview deployments per PR |
| **EAS Build** | Mobile CI builds | Expo's cloud build service; replaces local Xcode/Android Studio |
| **EAS Submit** | App store submission | Automated App Store + Play Store submission |
| **EAS Update** | OTA updates | Push JS bundle updates without app store review |

### Infrastructure as Code

| Tool | Role | Notes |
|---|---|---|
| **OpenTofu** | IaC | Open-source Terraform fork (MPL-2.0, no BSL). All Azure resources. |
| **Azure** | Cloud provider | $150/month credits; hosts self-hosted Supabase |
| **Azure Blob Storage** | OpenTofu state backend | Remote state; no Terraform Cloud needed |
| **Azure Key Vault** | Secrets management | All credentials at runtime; never in env files or CI secrets |

**Hard rule**: No manual Azure portal provisioning. Every resource is defined in OpenTofu.
`tofu apply` from scratch must produce a fully working environment.

Standard environment strategy: dev / staging / prod as OpenTofu workspaces on the same
Azure subscription. Separate Supabase databases per environment on the same Postgres instance.

### Transactional Email

| Tool | Role | Notes |
|---|---|---|
| **Resend** | SMTP / email API | Supabase self-hosted requires an SMTP provider for auth emails |

Free tier: 3,000 emails/month. Supabase SMTP config points at Resend.

### Observability

| Tool | Role | Notes |
|---|---|---|
| **New Relic** | Full-stack observability | APM, logs, traces, dashboards, alerts, browser monitoring, React Native monitoring |

Free tier: 100 GB/month data ingest, covers all small projects. One agent/SDK covers
everything — no need to stitch multiple tools together at prototype stage.

New Relic + Sentry is not required for prototypes. Add Sentry per-project when it reaches
real users and error management workflow (assign, track regressions, replay) becomes necessary.

### Product Analytics & Feature Flags

| Tool | Role | Notes |
|---|---|---|
| **PostHog** | Analytics, session replay, feature flags, A/B testing, surveys | |

**PostHog replaces**: Mixpanel (analytics) + FullStory (replay) + LaunchDarkly (flags) +
Optimizely (experiments) — in one tool, on one free tier.

Free tier (cloud): 1M events/month + 5K session recordings/month + 1M flag requests/month.
Covers 10-15 small prototypes entirely at $0.

Key uses per project:
- **Autocapture** — enable on day 1; understand user behavior before you've planned your event taxonomy
- **Feature flags** — kill bad features without a deploy; roll out to 5% to test; A/B test flows
- **Session replay** — watch what users actually do; invaluable for prototype validation
- **Surveys** — ask users why they did or didn't do something; NPS, PMF score

PostHog and New Relic answer different questions:
- New Relic: "Is the system healthy? What broke?"
- PostHog: "Are users doing what we expected? Why not?"

### CI/CD

| Tool | Role | Notes |
|---|---|---|
| **GitHub Actions** | CI/CD orchestration | `tofu plan` on PR, `tofu apply` on merge; runs tests; triggers EAS builds |
| **Vercel** | Web deploy | Automatic from GitHub push; no GHA config needed |

### Code Quality

| Tool | Role |
|---|---|
| **ESLint** | Linting (shared config in `packages/config/`) |
| **Prettier** | Formatting |
| **TypeScript strict mode** | Type checking |

---

## What's Deliberately Not In This Stack

| Tool | Why Excluded |
|---|---|
| Next.js (default) | Vite SPA is simpler for prototypes; use Next.js only when SSR/SSG is explicitly needed |
| Custom ORM (Prisma, Drizzle) | `@supabase/supabase-js` is sufficient; add an ORM when a project graduates |
| Redux / complex state management | Zustand or React Query sufficient for prototypes |
| Kubernetes / Helm | Overkill; Supabase runs on a single VM or Container Apps for prototypes |
| Terraform Cloud | Azure Blob Storage backend covers state needs without another vendor |
| Sentry (default) | New Relic covers error needs for prototypes; add Sentry when warranted |
| Separate feature flag tool | PostHog flags cover prototype needs |

---

## Quick-Start Checklist for a New Rig

When the Architect sets up a new rig, verify these are in place:

- [ ] pnpm workspace with `apps/web`, `apps/mobile`, `packages/` structure
- [ ] Turborepo `turbo.json` with build/dev/lint/test pipelines
- [ ] Shared TypeScript config (`packages/config/tsconfig/`)
- [ ] Shared ESLint + Prettier config
- [ ] Supabase project created (self-hosted, separate DB for this rig)
- [ ] OpenTofu module for this rig's Azure resources
- [ ] Azure Key Vault wired; no secrets in `.env` committed to repo
- [ ] Resend SMTP wired to Supabase auth config
- [ ] New Relic agent installed in web app, mobile app, and any edge functions
- [ ] PostHog SDK installed in web app and mobile app; `posthog.identify()` called on auth
- [ ] Vercel project connected to GitHub repo (web auto-deploy)
- [ ] EAS project configured (`eas.json` with dev/staging/prod profiles)
- [ ] GitHub Actions: `tofu plan` on PR, `tofu apply` on merge to main
- [ ] Feature flag: at least one PostHog flag gating the first new feature

---

## Version

Last updated: 2026-04-10
Maintained by: marcus (gasworks crew)
