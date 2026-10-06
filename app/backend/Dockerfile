# --- Étape de build ---
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/install -r requirements.txt

# --- Étape finale, minimale ---
FROM python:3.12-slim
RUN useradd --uid 10001 --create-home appuser
WORKDIR /app
COPY --from=builder /install /usr/local/lib/python3.12/site-packages
COPY app.py .
RUN chown -R appuser:appuser /app
USER 10001
EXPOSE 5000
CMD ["python", "app.py"]
