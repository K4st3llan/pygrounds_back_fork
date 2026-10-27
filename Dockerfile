FROM python:3.12-slim

RUN apt-get update && apt-get install -y poppler-utils libmagic1 libgl1 libglib2.0-0 && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EXPOSE 8000
CMD ["sh", "-c", "exec gunicorn pygrounds_backend_new.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers 1 --timeout 120"]