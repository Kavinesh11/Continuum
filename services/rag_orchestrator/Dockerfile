FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.11-slim
RUN groupadd -r appgroup && useradd -r -g appgroup appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY . ./svc/
ENV PYTHONPATH=/app
USER appuser
EXPOSE 8001
CMD ["uvicorn", "svc.app:app", "--host", "0.0.0.0", "--port", "8001"]
