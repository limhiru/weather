"""KMA adapter. Python 3.11+, standard library only; all dates are KST."""
import math
import json
import os
import threading
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode, unquote
from urllib.request import urlopen

KST = timezone(timedelta(hours=9))
BASE = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/"


class WeatherError(Exception):
    def __init__(self, message, status=502):
        super().__init__(message)
        self.status = status


def grid(lat, lon):
    """KMA Lambert conformal conic, 5 km grid (DFS)."""
    if not math.isfinite(lat) or not math.isfinite(lon) or not (33 <= lat <= 39.5 and 124 <= lon <= 132):
        raise WeatherError("기상청 예보는 대한민국 지역에서 이용할 수 있어요.", 400)
    rad = math.pi / 180
    re, slat1, slat2 = 6371.00877 / 5, 30 * rad, 60 * rad
    sn = math.log(math.cos(slat1) / math.cos(slat2)) / math.log(math.tan(math.pi / 4 + slat2 / 2) / math.tan(math.pi / 4 + slat1 / 2))
    sf = math.tan(math.pi / 4 + slat1 / 2) ** sn * math.cos(slat1) / sn
    ro = re * sf / math.tan(math.pi / 4 + 38 * rad / 2) ** sn
    ra = re * sf / math.tan(math.pi / 4 + lat * rad / 2) ** sn
    theta = (lon - 126) * rad * sn
    return math.floor(ra * math.sin(theta) + 43.5), math.floor(ro - ra * math.cos(theta) + 136.5)


def issue_times(now):
    now = now.astimezone(KST)
    # Observation availability: :40. Forecast: 02/05/08/.../23 + 10min.
    observation = (now - timedelta(minutes=40)).replace(minute=0, second=0, microsecond=0)
    available = now - timedelta(minutes=10)
    forecast = available.replace(hour=23, minute=0, second=0, microsecond=0) - timedelta(days=1)
    for hour in (2, 5, 8, 11, 14, 17, 20, 23):
        candidate = available.replace(hour=hour, minute=0, second=0, microsecond=0)
        if candidate <= available:
            forecast = candidate
    return observation, forecast


def condition(sky, pty):
    if str(pty) in ("3", "7"):
        return "snow"
    if str(pty) in ("2", "6"):
        return "sleet"
    if str(pty) in ("1", "4", "5"):
        return "rain"
    return {"1": "clear", "3": "cloudy", "4": "overcast"}.get(str(sky), "cloudy")


def number(value):
    try:
        result = float(value)
        return result if math.isfinite(result) and result > -900 else None
    except (TypeError, ValueError):
        return None


def fetch(operation, issue, nx, ny, key):
    params = dict(serviceKey=unquote(key), pageNo=1, numOfRows=2000, dataType="JSON",
                  base_date=issue.strftime("%Y%m%d"), base_time=issue.strftime("%H%M"), nx=nx, ny=ny)
    try:
        with urlopen(BASE + operation + "?" + urlencode(params), timeout=18) as response:
            payload = json.load(response)["response"]
        code = str(payload["header"]["resultCode"])
        if code not in ("00", "0"):
            if code == "03":
                raise WeatherError("기상청에서 아직 이 시각의 자료를 발표하지 않았어요.")
            raise WeatherError("기상청 요청을 처리하지 못했어요. 서버의 인증키·활용승인·호출 한도를 확인해 주세요.")
        rows = payload["body"]["items"]["item"]
        return rows if isinstance(rows, list) else [rows]
    except WeatherError:
        raise
    except Exception:
        # Never expose a request URL: it contains the credential.
        raise WeatherError("기상청에 연결할 수 없어요. 잠시 뒤 다시 시도해 주세요.") from None


def normalize(observations, forecasts, now, observed, issued):
    obs = {row["category"]: row["obsrValue"] for row in observations}
    slots = defaultdict(dict)
    for row in forecasts:
        stamp = datetime.strptime(row["fcstDate"] + row["fcstTime"], "%Y%m%d%H%M").replace(tzinfo=KST)
        slots[stamp][row["category"]] = row["fcstValue"]
    current_hour = now.astimezone(KST).replace(minute=0, second=0, microsecond=0)
    hours = []
    for stamp, values in sorted(slots.items()):
        if stamp < current_hour or number(values.get("TMP")) is None:
            continue
        hours.append(dict(time=stamp.isoformat(), temperature=number(values.get("TMP")),
                          condition=condition(values.get("SKY"), values.get("PTY")),
                          precipitationProbability=number(values.get("POP"))))
    if number(obs.get("T1H")) is None or not hours:
        raise WeatherError("기상청 자료가 아직 완전하지 않아요. 잠시 뒤 새로고침해 주세요.")
    days = []
    by_day = defaultdict(list)
    for hour in hours:
        by_day[hour["time"][:10]].append(hour)
    for date, rows in by_day.items():
        temperatures = [r["temperature"] for r in rows]
        # Display honest remaining-forecast ranges, not invented daily extrema.
        days.append(dict(date=date, low=min(temperatures), high=max(temperatures),
                         condition=max(rows, key=lambda r: {"clear": 0, "cloudy": 1, "overcast": 2, "rain": 3, "sleet": 4, "snow": 5}[r["condition"]])["condition"],
                         precipitationProbability=max((r["precipitationProbability"] for r in rows if r["precipitationProbability"] is not None), default=None)))
    nearest = min(slots, key=lambda stamp: abs((stamp - now).total_seconds()))
    return dict(source="기상청", isDemo=False, observedAt=observed.isoformat(), forecastIssuedAt=issued.isoformat(),
                fetchedAt=now.isoformat(), current=dict(temperature=number(obs.get("T1H")),
                humidity=number(obs.get("REH")), windSpeed=number(obs.get("WSD")),
                precipitation=number(obs.get("RN1")), condition=condition(slots[nearest].get("SKY"), obs.get("PTY"))),
                hourly=hours[:24], daily=days)


class WeatherService:
    def __init__(self):
        self.cache = {}
        self.lock = threading.Lock()

    def get(self, lat, lon):
        nx, ny = grid(lat, lon)
        key = os.environ.get("KMA_SERVICE_KEY", "").strip()
        if not key:
            raise WeatherError("서버에 기상청 인증키를 등록해 주세요. 설정에서 디자인 미리보기도 볼 수 있어요.", 503)
        with self.lock:
            cached = self.cache.get((nx, ny))
            if cached and time.monotonic() - cached[0] < 300:
                return cached[1]
            now = datetime.now(KST)
            observation, forecast = issue_times(now)
            observations = fetch("getUltraSrtNcst", observation, nx, ny, key)
            forecasts = fetch("getVilageFcst", forecast, nx, ny, key)
            result = normalize(observations, forecasts, now, observation, forecast)
            if len(self.cache) >= 512:
                self.cache.pop(next(iter(self.cache)))
            self.cache[nx, ny] = (time.monotonic(), result)
            return result
