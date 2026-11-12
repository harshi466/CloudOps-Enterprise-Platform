FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py forecast.py wsgi.py ./
RUN useradd -r -u 10001 appuser
USER 10001
EXPOSE 5002
HEALTHCHECK CMD python -c "import urllib.request;urllib.request.urlopen('http://localhost:5002/health')"
CMD ["gunicorn", "-b", "0.0.0.0:5002", "-w", "2", "wsgi:app"]
