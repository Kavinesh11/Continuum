FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . ./svc/

ENV PYTHONPATH=/app

CMD ["python", "-m", "svc.kafka_consumer"]
