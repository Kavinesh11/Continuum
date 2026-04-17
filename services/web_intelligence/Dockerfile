FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY . ./services/web_intelligence/
RUN touch services/__init__.py services/web_intelligence/__init__.py 2>/dev/null || true
ENV PYTHONPATH=/app
USER appuser
CMD ["python", "-m", "services.web_intelligence.service"]
