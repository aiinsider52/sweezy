# SWEEEZY Backend (FastAPI)

Production-ready FastAPI backend for the SwiftUI app. Provides Guides, Checklists, Templates, Appointments, and RemoteConfig APIs with JWT auth, SQLAlchemy 2.x, Alembic, PostgreSQL, and Sentry.

## Features
- FastAPI + SQLAlchemy 2.x + Alembic + PostgreSQL
- JWT auth (python-jose, passlib) — simple admin flow via env
- CORS, Pydantic v2
- Background tasks on lifespan
- Sentry integration
- Dockerfile included

## Getting Started

### 1) Setup
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r backend/requirements.txt
cp backend/.env.example backend/.env
```
Edit `backend/.env` as needed (DATABASE_URL, JWT_SECRET_KEY, etc).

### 2) Database
- Start Postgres locally or use Docker
- Initialize tables via Alembic (recommended):
```bash
alembic -c backend/alembic.ini revision --autogenerate -m "init"
alembic -c backend/alembic.ini upgrade head
```

### 3) Seed Demo Data
```bash
python backend/scripts/seed_demo_data.py
```

### 4) Run
```bash
uvicorn backend.app.main:app --reload --port 8000
```

OpenAPI docs: http://localhost:8000/docs

### 5) Auth
Obtain token:
```bash
curl -X POST http://localhost:8000/auth/token -d 'username=admin@sweeezy.app&password=admin123' -H 'Content-Type: application/x-www-form-urlencoded'
```
Use `Authorization: Bearer <token>` for protected operations (create/update/delete).

### 6) Generate OpenAPI JSON
```bash
python backend/scripts/generate_openapi.py
```
Outputs `shared/openapi.json` at the repo root.

### 7) Jobs Copilot

Jobs use a normalized PostgreSQL catalog, scheduled provider sync, server favorites,
application tracking, alerts, employer publishing/moderation, reports, semantic matching,
and direct employer chat. Configure only licensed feeds. Deployment, monitoring, recovery,
and launch checks: [JOBS_RUNBOOK.md](JOBS_RUNBOOK.md).

### Docker
```bash
docker build -t sweeezy-backend -f backend/Dockerfile .
docker run --rm -p 8000:8000 --env-file backend/.env sweeezy-backend
```

## Project Structure
```
backend/
  app/
    main.py
    routers/
    models/
    schemas/
    services/
    core/
    dependencies.py
  alembic/
  Dockerfile
  requirements.txt
  .env.example
  README.md
```

## Notes
- Admin credentials are read from env for demo purposes. Replace with a real user store in production.
- Use Alembic migrations to manage schema changes. The seed script calls `create_all` for local/dev convenience only.
