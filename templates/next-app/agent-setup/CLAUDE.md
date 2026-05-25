# {{PROJECT_NAME}} — Agent Setup

This is a Next.js web application scaffolded from the octo `next-app` template.

## Project Context

- **Framework**: Next.js 14 with App Router
- **Language**: TypeScript
- **Styling**: Add your preferred CSS solution (Tailwind, CSS Modules, etc.)

## App Router Conventions

- Pages live under `app/` using the file-based routing system
- `app/layout.tsx` — root layout (required)
- `app/page.tsx` — home page (`/` route)
- `app/[route]/page.tsx` — nested routes
- Server Components are the default; add `"use client"` directive only when needed (event handlers, browser APIs, hooks)
- `app/api/[route]/route.ts` — API route handlers
- `components/` — shared UI components
- `lib/` — utility functions and shared logic

## Development

```bash
npm install
npm run dev      # start dev server at http://localhost:3000
npm run build    # production build
npm run lint     # run ESLint
```

## Autonomous Agent Instructions

If a `session.md` file is present at the repo root, read it first and execute the described task autonomously. Do not ask clarifying questions — use your best judgment based on the spec and context provided. When the task is complete (success or failure), write a `result.md` file to the repo root using exactly this schema:

```
status: success | failed
pr_url: <url or null>
summary: <one paragraph>
```

Push the feature branch and open a PR before writing `result.md` on success.
