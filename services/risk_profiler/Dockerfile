FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Since Risk Profiler acts primarily as a library/worker and 
# lacks a persistent Web API like main.py in this folder,
# we run a keep-alive tail process so the container stays up in AWS.
CMD ["tail", "-f", "/dev/null"]
