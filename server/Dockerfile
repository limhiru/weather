FROM python:3.12-slim
WORKDIR /app
COPY server /app/server
RUN useradd --create-home weather
USER weather
ENV HOST=0.0.0.0 PORT=8080 PYTHONUNBUFFERED=1
EXPOSE 8080
CMD ["python", "-m", "server.app"]
