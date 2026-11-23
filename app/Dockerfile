FROM python:3.12-slim
ARG APP_VERSION=dev
ARG APP_BROKEN=false
ENV PYTHONUNBUFFERED=1 APP_VERSION=${APP_VERSION} APP_BROKEN=${APP_BROKEN}
RUN useradd --system app && apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
USER app
EXPOSE 8000
HEALTHCHECK --interval=5s --timeout=2s --retries=3 CMD curl -fsS localhost:8000/health || exit 1
CMD ["gunicorn", "-b", "0.0.0.0:8000", "-w", "2", "main:app"]
