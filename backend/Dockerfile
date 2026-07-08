FROM python:3.12-slim

WORKDIR /app

# psql: AeroGo has no ORM/migration runner (raw psycopg2 SQL in db.py), so the
# schema files under database/postgres/*.sql are applied at container startup
# below instead of via docker-entrypoint-initdb.d (works whether this app has
# its own dedicated Postgres or shares one instance with other apps).
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-client \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

COPY backend /app/backend
COPY database/postgres /app/database/postgres

EXPOSE 8000

# 01,02,04,05,06 순서로 적용 (03/05는 내용상 no-op). 전부 CREATE TABLE IF NOT EXISTS /
# ON CONFLICT 기반이라 재기동 시 다시 실행해도 안전합니다.
CMD sh -c '\
    for f in 01_schema.sql 02_seed.sql 04_public_game_records_seed.sql 05_user_preferences.sql 06_auth_sessions.sql; do \
        PGPASSWORD="$POSTGRES_PASSWORD" psql -v ON_ERROR_STOP=1 \
            -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" -d "$POSTGRES_DATABASE" \
            -f "/app/database/postgres/$f"; \
    done && \
    uvicorn backend.app.main:app --host 0.0.0.0 --port 8000'
