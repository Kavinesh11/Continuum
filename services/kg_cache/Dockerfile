FROM python:3.12-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv

RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /app
COPY requirements.txt .
RUN uv pip install --system -r requirements.txt

COPY main.py cache.py ./
USER appuser
EXPOSE 8080
CMD ["python", "main.py"]
