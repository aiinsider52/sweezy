FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install --upgrade pip && pip install -r /app/requirements.txt

# copy backend source into /app/backend (this Dockerfile sits in backend/)
COPY . /app/backend

ENV MODULE_NAME=backend.app.main:app
ENV HOST=0.0.0.0
ENV PORT=8000

EXPOSE 8000

# Run Alembic migrations then start the app. Use Render's PORT if provided.
CMD ["sh", "-c", "if [ -d alembic ]; then alembic upgrade head; fi && uvicorn backend.app.main:app --host 0.0.0.0 --port $PORT"]


