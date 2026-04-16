FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . ./services/web_intelligence/
RUN touch services/__init__.py services/web_intelligence/__init__.py 2>/dev/null || true

ENV PYTHONPATH=/app

CMD ["python", "-m", "services.web_intelligence.service"]
