# Sweezy Admin (Next.js 14)

Production-ready admin dashboard wired to FastAPI (`/api/v1`).

## Stack
- Next.js 14 App Router, TypeScript
- TailwindCSS, minimal shadcn-like components
- React Query, Zustand
- Light/Dark via `next-themes`

## Quick start

```bash
cd admin
cp .env.local.example .env.local   # set NEXT_PUBLIC_API_URL if needed
npm install
npm run dev
```

Open http://localhost:9876/login

- Login posts to FastAPI → sets HttpOnly `access_token` cookie via Next route `/api/auth/login`.
- Middleware protects `/admin/*` routes.

## Structure
```
admin/
  app/
    login/page.tsx
    admin/dashboard/page.tsx
    admin/users/page.tsx
    api/auth/login/route.ts
  components/{Sidebar,Header,Card,DataTable}.tsx
  lib/{api,auth,utils}.ts
  store/useAuth.ts
  middleware.ts
```

## Notes
- Users table expects a GET `${API_URL}/users` endpoint (JWT). If not present it shows empty list. Creating a user uses `${API_URL}/auth/register`.
- To logout, use button in header.


