"""Run from repository root: python3 -m server.app."""
import json
import os
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit
from .weather import WeatherService, WeatherError


def load_env():
    path = Path(__file__).with_name(".env")
    if path.exists():
        for line in path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip().strip("\"'"))


service = WeatherService()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        route = urlsplit(self.path)
        try:
            if route.path == "/health":
                self.respond(200, {"status": "ok", "configured": bool(os.getenv("KMA_SERVICE_KEY"))})
                return
            if route.path != "/v1/weather":
                self.respond(404, {"error": "찾을 수 없는 주소예요."})
                return
            params = parse_qs(route.query)
            lat, lon = float(params["lat"][0]), float(params["lon"][0])
            self.respond(200, service.get(lat, lon))
        except (KeyError, ValueError):
            self.respond(400, {"error": "올바른 위도(lat)와 경도(lon)가 필요해요."})
        except WeatherError as error:
            self.respond(error.status, {"error": str(error)})
        except Exception:
            self.respond(500, {"error": "날씨를 처리하지 못했어요. 다시 시도해 주세요."})

    def respond(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # Do not log precise location query strings.


if __name__ == "__main__":
    load_env()
    host, port = os.getenv("HOST", "127.0.0.1"), int(os.getenv("PORT", "8080"))
    print(f"Weather server: http://{host}:{port} (KMA key configured: {bool(os.getenv('KMA_SERVICE_KEY'))})", flush=True)
    ThreadingHTTPServer((host, port), Handler).serve_forever()
