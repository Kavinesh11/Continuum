FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Shared volume for the unix socket will be mounted via docker-compose
CMD ["python", "sidecar.py"]
