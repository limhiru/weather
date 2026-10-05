# Weather API v1

`GET /v1/weather?lat=37.5665&lon=126.978`

정상 응답의 필수 필드:

| 필드 | 의미 |
|---|---|
| source / isDemo | `기상청` / `false` (서버는 데모를 반환하지 않음) |
| observedAt | 관측 자료 발표 시각, ISO 8601 +09:00 |
| forecastIssuedAt | 단기예보 발표 시각 |
| fetchedAt | 서버 최초 조회 시각 (캐시 응답에서 유지) |
| current | temperature (°C), humidity (%), windSpeed (m/s), precipitation (mm/1h), condition |
| hourly | time, temperature, condition, precipitationProbability (%) |
| daily | date, low, high, condition, precipitationProbability (%) |

`condition`: `clear`, `cloudy`, `overcast`, `rain`, `snow`, `sleet`.
숫자 누락은 null. daily의 condition은 해당 날짜 예보 중 강수/눈 등을 우선 표시한 요약입니다.
오류 응답은 `{"error":"사용자에게 표시할 한국어 메시지"}` 입니다.

- 400: 잘못된 좌표 / 서비스 영역 밖
- 404: 존재하지 않는 경로
- 502: 기상청 네트워크/응답/승인 오류 또는 불완전한 데이터
- 503: 서버 인증키 미설정

현재 인증 없이 사용할 수 있는 개인용 서버입니다. 512격자 제한의 5분 메모리 캐시를 사용하고, 동시에 같은 격자로 요청이 들어와도 중복 기상청 호출을 억제합니다. 모든 격자 miss는 한 번에 하나씩 처리하므로 공개 트래픽용 서버는 별도 확장이 필요합니다.
