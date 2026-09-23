FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DBT_PROFILES_DIR=/app

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir dbt-athena-community

COPY . /app/

ENTRYPOINT ["dbt"]
CMD ["run"]