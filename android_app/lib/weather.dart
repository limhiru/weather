import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Place {
  final String name, region;
  final double lat, lon;
  const Place(this.name, this.region, this.lat, this.lon);
}

const places = [
  Place('서울', '대한민국 · 서울특별시', 37.5665, 126.978),
  Place('부산', '대한민국 · 부산광역시', 35.1796, 129.0756),
  Place('인천', '대한민국 · 인천광역시', 37.4563, 126.7052),
  Place('대구', '대한민국 · 대구광역시', 35.8714, 128.6014),
  Place('대전', '대한민국 · 대전광역시', 36.3504, 127.3845),
  Place('광주', '대한민국 · 광주광역시', 35.1595, 126.8526),
  Place('제주', '대한민국 · 제주특별자치도', 33.4996, 126.5312),
  Place('강릉', '대한민국 · 강원특별자치도', 37.7519, 128.8761),
  Place('수원', '대한민국 · 경기도', 37.2636, 127.0286),
  Place('울산', '대한민국 · 울산광역시', 35.5384, 129.3114),
  Place('전주', '대한민국 · 전북특별자치도', 35.8242, 127.148),
  Place('청주', '대한민국 · 충청북도', 36.6424, 127.489),
];
String conditionLabel(String value) =>
    const {
      'clear': '맑음',
      'cloudy': '구름 많음',
      'overcast': '흐림',
      'rain': '비',
      'snow': '눈',
      'sleet': '비와 눈',
    }[value] ??
    '날씨';
String numberText(num? value, [String unit = '']) =>
    value == null ? '—' : '${value.round()}$unit';
DateTime koreanTime(String value) =>
    DateTime.parse(value).toUtc().add(const Duration(hours: 9));

num? dewPointTemperature(Map<String, dynamic> current) {
  final temperature = num.tryParse(current['temperature']?.toString() ?? '');
  final humidity = num.tryParse(current['humidity']?.toString() ?? '');
  if (temperature == null ||
      humidity == null ||
      !temperature.isFinite ||
      !humidity.isFinite ||
      humidity <= 0 ||
      humidity > 100) {
    return null;
  }
  final gamma =
      math.log(humidity / 100) + 17.625 * temperature / (243.04 + temperature);
  return 243.04 * gamma / (17.625 - gamma);
}

class WeatherData {
  final Map<String, dynamic> json;
  WeatherData(this.json);
  Map<String, dynamic> get current =>
      Map<String, dynamic>.from(json['current']);
  List<Map<String, dynamic>> get hourly =>
      List<Map<String, dynamic>>.from(json['hourly']);
  List<Map<String, dynamic>> get daily =>
      List<Map<String, dynamic>>.from(json['daily']);
  String get condition => current['condition'];
  bool get isDemo => json['isDemo'] == true;
  String get updated {
    final date = koreanTime(json['observedAt']);
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static WeatherData demo(String condition) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final base = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).subtract(const Duration(hours: 9));
    final temperatures = [21, 22, 23, 23, 22, 21, 20, 19, 18, 18, 17, 18];
    const humidity = [58, 55, 52, 50, 48, 47, 50, 54, 59, 63, 66, 62];
    const windSpeed = [
      1.4,
      1.7,
      2.0,
      2.3,
      2.6,
      2.4,
      2.1,
      1.8,
      1.5,
      1.3,
      1.6,
      1.9,
    ];
    const windDirection = [
      '북동',
      '북동',
      '동북동',
      '동',
      '동남동',
      '동',
      '남동',
      '남',
      '남남서',
      '서남서',
      '서',
      '북서',
    ];
    return WeatherData({
      'isDemo': true,
      'source': '디자인 미리보기',
      'observedAt': base.toIso8601String(),
      'current': {
        'temperature': 21,
        'humidity': 68,
        'windSpeed': 2.4,
        'precipitation': condition == 'rain' ? 1.5 : 0,
        'condition': condition,
      },
      'hourly': List.generate(
        12,
        (i) => {
          'time': base.add(Duration(hours: i)).toIso8601String(),
          'temperature': temperatures[i],
          'condition': condition,
          'precipitationProbability': condition == 'rain' ? 80 : 10,
          'humidity': humidity[i],
          'windSpeed': windSpeed[i],
          'windDirection': windDirection[i],
        },
      ),
      'daily': List.generate(
        4,
        (i) => {
          'date': DateTime(
            now.year,
            now.month,
            now.day + i,
          ).toIso8601String().substring(0, 10),
          'low': 16 + i,
          'high': 23 + i,
          'condition': condition,
          'precipitationProbability': condition == 'rain' ? 80 : 10,
        },
      ),
    });
  }
}

bool validEndpoint(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    return false;
  }
  return uri.scheme == 'https' ||
      (uri.scheme == 'http' &&
          ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host));
}

class WeatherApi {
  static const credentials = FlutterSecureStorage();

  Future<WeatherData> fetch(
    String endpoint,
    Place place, {
    String? apiKey,
  }) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      return _fetchKma(apiKey, place);
    }
    if (!validEndpoint(endpoint)) {
      throw Exception('설정에서 HTTPS 날씨 서버 주소를 입력해 주세요.');
    }
    final uri = Uri.parse(endpoint).replace(
      path: '/v1/weather',
      queryParameters: {'lat': '${place.lat}', 'lon': '${place.lon}'},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 45));
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(json['error'] ?? '날씨를 불러오지 못했어요.');
    }
    return WeatherData(json);
  }

  Future<WeatherData> _fetchKma(String key, Place place) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final kstNow = DateTime.utc(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    final available = kstNow.subtract(const Duration(minutes: 10));
    final observed = kstNow.subtract(const Duration(minutes: 40));
    final observationIssue = DateTime.utc(
      observed.year,
      observed.month,
      observed.day,
      observed.hour,
    );
    var forecastIssue = DateTime.utc(
      available.year,
      available.month,
      available.day,
      23,
    ).subtract(const Duration(days: 1));
    for (final hour in [2, 5, 8, 11, 14, 17, 20, 23]) {
      final candidate = DateTime.utc(
        available.year,
        available.month,
        available.day,
        hour,
      );
      if (!candidate.isAfter(available)) forecastIssue = candidate;
    }
    final nxNy = _grid(place.lat, place.lon);
    final ultraAvailable = kstNow.subtract(const Duration(minutes: 45));
    final ultraIssue = DateTime.utc(
      ultraAvailable.year,
      ultraAvailable.month,
      ultraAvailable.day,
      ultraAvailable.hour,
      ultraAvailable.minute >= 30 ? 30 : 0,
    );
    final observations = await _request(
      'getUltraSrtNcst',
      key,
      observationIssue,
      nxNy,
    );
    final forecasts = await _request('getVilageFcst', key, forecastIssue, nxNy);
    List<Map<String, dynamic>> ultraForecasts = [];
    try {
      ultraForecasts = await _request('getUltraSrtFcst', key, ultraIssue, nxNy);
    } catch (_) {
      // The regular hourly forecast remains available if the latest rapid cycle is delayed.
    }
    final obs = {
      for (final row in observations)
        row['category'].toString(): row['obsrValue'],
    };
    final slots = <DateTime, Map<String, dynamic>>{};
    for (final row in forecasts) {
      final date = row['fcstDate'].toString();
      final time = row['fcstTime'].toString().padLeft(4, '0');
      final stamp = DateTime.utc(
        int.parse(date.substring(0, 4)),
        int.parse(date.substring(4, 6)),
        int.parse(date.substring(6, 8)),
        int.parse(time.substring(0, 2)),
        int.parse(time.substring(2, 4)),
      );
      (slots[stamp] ??= {})[row['category'].toString()] = row['fcstValue'];
    }
    final rapidSlots = <DateTime, Map<String, dynamic>>{};
    for (final row in ultraForecasts) {
      final date = row['fcstDate'].toString();
      final time = row['fcstTime'].toString().padLeft(4, '0');
      final stamp = DateTime.utc(
        int.parse(date.substring(0, 4)),
        int.parse(date.substring(4, 6)),
        int.parse(date.substring(6, 8)),
        int.parse(time.substring(0, 2)),
        int.parse(time.substring(2, 4)),
      );
      (rapidSlots[stamp] ??= {})[row['category'].toString()] = row['fcstValue'];
    }
    final currentHour = DateTime.utc(now.year, now.month, now.day, now.hour);
    final entries =
        slots.entries
            .where(
              (entry) =>
                  !entry.key.isBefore(currentHour) &&
                  _kmaNumber(entry.value['TMP']) != null,
            )
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final currentTemperature = _kmaNumber(obs['T1H']);
    if (currentTemperature == null || entries.isEmpty) {
      throw Exception('기상청 자료가 아직 준비되지 않았어요. 잠시 뒤 다시 새로고침해 주세요.');
    }
    final nearest = slots.keys.reduce(
      (a, b) =>
          (a.difference(kstNow).abs() < b.difference(kstNow).abs()) ? a : b,
    );
    String? amount(dynamic raw, String unit) {
      final value = raw?.toString();
      if (value == null || value.isEmpty || value == '-') return null;
      if (value == '0' ||
          value == '0.0' ||
          value == '강수없음' ||
          value == '적설없음') {
        return '없음';
      }
      final numeric = _kmaNumber(value);
      return numeric == null
          ? value
          : '${numeric == numeric.roundToDouble() ? numeric.toInt() : numeric}$unit';
    }

    final hourlyAll = entries.map((entry) {
      final rapid = rapidSlots[entry.key] ?? <String, dynamic>{};
      final sky = rapid['SKY'] ?? entry.value['SKY'];
      final pty = rapid['PTY'] ?? entry.value['PTY'];
      final vector = rapid['VEC'] ?? entry.value['VEC'];
      return {
        'time': _kstIso(entry.key),
        'temperature':
            _kmaNumber(rapid['T1H']) ?? _kmaNumber(entry.value['TMP']),
        'condition': _kmaCondition(sky, pty),
        'precipitationProbability': _kmaNumber(entry.value['POP']),
        'humidity': _kmaNumber(rapid['REH']) ?? _kmaNumber(entry.value['REH']),
        'windSpeed': _kmaNumber(rapid['WSD']) ?? _kmaNumber(entry.value['WSD']),
        'windDirectionDegrees': _kmaNumber(vector),
        'windDirection': _kmaDirection(vector),
        'precipitationAmount': amount(rapid['RN1'] ?? entry.value['PCP'], 'mm'),
        'snowAmount': amount(entry.value['SNO'], 'cm'),
        'waveHeight': _kmaNumber(entry.value['WAV']),
        'lightning': (_kmaNumber(rapid['LGT']) ?? 0) > 0,
        'temperatureMin': _kmaNumber(entry.value['TMN']),
        'temperatureMax': _kmaNumber(entry.value['TMX']),
      };
    }).toList();
    final hourly = hourlyAll.take(24).toList();
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final row in hourlyAll) {
      final date = row['time'].toString().substring(0, 10);
      (byDay[date] ??= []).add(row);
    }
    const severity = {
      'clear': 0,
      'cloudy': 1,
      'overcast': 2,
      'rain': 3,
      'sleet': 4,
      'snow': 5,
    };
    final daily = byDay.entries.map((day) {
      final temperatures = day.value
          .map((hour) => hour['temperature'] as num)
          .toList();
      final officialLows = day.value
          .map((hour) => hour['temperatureMin'] as num?)
          .whereType<num>()
          .toList();
      final officialHighs = day.value
          .map((hour) => hour['temperatureMax'] as num?)
          .whereType<num>()
          .toList();
      final conditions =
          day.value.map((hour) => hour['condition'] as String).toList()
            ..sort((a, b) => severity[b]!.compareTo(severity[a]!));
      final pops = day.value
          .map((hour) => hour['precipitationProbability'] as num?)
          .whereType<num>()
          .toList();
      return {
        'date': day.key,
        'low': officialLows.isEmpty
            ? temperatures.reduce((a, b) => a < b ? a : b)
            : officialLows.first,
        'high': officialHighs.isEmpty
            ? temperatures.reduce((a, b) => a > b ? a : b)
            : officialHighs.first,
        'condition': conditions.first,
        'precipitationProbability': pops.isEmpty
            ? null
            : pops.reduce((a, b) => a > b ? a : b),
      };
    }).toList();
    final currentPty = obs['PTY']?.toString() ?? slots[nearest]?['PTY'];
    final rain = amount(obs['RN1'], 'mm');
    return WeatherData({
      'source': '기상청',
      'isDemo': false,
      'observedAt': _kstIso(observationIssue),
      'forecastIssuedAt': _kstIso(forecastIssue),
      'ultraForecastIssuedAt': ultraForecasts.isEmpty
          ? null
          : _kstIso(ultraIssue),
      'fetchedAt': _kstIso(kstNow),
      'current': {
        'temperature': currentTemperature,
        'humidity': _kmaNumber(obs['REH']),
        'windSpeed': _kmaNumber(obs['WSD']),
        'windDirectionDegrees': _kmaNumber(obs['VEC']),
        'windDirection': _kmaDirection(obs['VEC']),
        'windEastWest': _kmaNumber(obs['UUU']),
        'windNorthSouth': _kmaNumber(obs['VVV']),
        'precipitation': rain,
        'precipitationType': _kmaPrecipitationType(currentPty),
        'condition': _kmaCondition(slots[nearest]?['SKY'], currentPty),
      },
      'hourly': hourly,
      'daily': daily,
    });
  }

  Future<List<Map<String, dynamic>>> _request(
    String operation,
    String key,
    DateTime issue,
    (int, int) grid,
  ) async {
    final date =
        '${issue.year.toString().padLeft(4, '0')}${issue.month.toString().padLeft(2, '0')}${issue.day.toString().padLeft(2, '0')}';
    final time = '${issue.hour.toString().padLeft(2, '0')}00';
    final uri = Uri.https(
      'apis.data.go.kr',
      '/1360000/VilageFcstInfoService_2.0/$operation',
      {
        'serviceKey': key,
        'pageNo': '1',
        'numOfRows': '2000',
        'dataType': 'JSON',
        'base_date': date,
        'base_time': time,
        'nx': '${grid.$1}',
        'ny': '${grid.$2}',
      },
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 25));
      final root =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final body = root['response'] as Map<String, dynamic>?;
      final header = body?['header'] as Map<String, dynamic>?;
      final code = header?['resultCode']?.toString();
      if (response.statusCode != 200 || (code != '00' && code != '0')) {
        throw Exception('기상청 요청에 실패했어요. 인증키·활용 신청·호출 한도를 확인해 주세요.');
      }
      final items =
          (body?['body'] as Map<String, dynamic>?)?['items']
              as Map<String, dynamic>?;
      final raw = items?['item'];
      if (raw is List) return raw.cast<Map<String, dynamic>>();
      if (raw is Map<String, dynamic>) return [raw];
      throw Exception('기상청에서 아직 예보 자료를 발표하지 않았어요. 잠시 뒤 다시 시도해 주세요.');
    } on TimeoutException {
      throw Exception('기상청 응답이 늦어지고 있어요. 잠시 뒤 다시 시도해 주세요.');
    } on FormatException {
      throw Exception('기상청 응답을 읽지 못했어요. 인증키와 활용 신청 상태를 확인해 주세요.');
    }
  }

  (int, int) _grid(double lat, double lon) {
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat < 33 ||
        lat > 39.5 ||
        lon < 124 ||
        lon > 132) {
      throw Exception('기상청 예보는 대한민국 지역에서 이용할 수 있어요.');
    }
    const d = 3.141592653589793 / 180;
    const re = 6371.00877 / 5, slat1 = 30 * d, slat2 = 60 * d;
    final sn =
        math.log(math.cos(slat1) / math.cos(slat2)) /
        math.log(
          math.tan(math.pi / 4 + slat2 / 2) / math.tan(math.pi / 4 + slat1 / 2),
        );
    final sf =
        math.pow(math.tan(math.pi / 4 + slat1 / 2), sn) * math.cos(slat1) / sn;
    final ro = re * sf / math.pow(math.tan(math.pi / 4 + 38 * d / 2), sn);
    final ra = re * sf / math.pow(math.tan(math.pi / 4 + lat * d / 2), sn);
    final theta = (lon - 126) * d * sn;
    return (
      (ra * math.sin(theta) + 43.5).floor(),
      (ro - ra * math.cos(theta) + 136.5).floor(),
    );
  }

  String _kstIso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}T${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:00+09:00';
  num? _kmaNumber(dynamic value) {
    final n = num.tryParse(value?.toString() ?? '');
    return n == null || !n.isFinite || n <= -900 ? null : n;
  }

  String _kmaPrecipitationType(dynamic raw) =>
      switch (int.tryParse(raw?.toString() ?? '0') ?? 0) {
        1 || 5 => '비',
        2 || 6 => '비와 눈',
        3 || 7 => '눈',
        4 => '소나기',
        _ => '없음',
      };

  String? _kmaDirection(dynamic raw) {
    final degrees = _kmaNumber(raw);
    if (degrees == null) return null;
    const directions = [
      '북',
      '북북동',
      '북동',
      '동북동',
      '동',
      '동남동',
      '남동',
      '남남동',
      '남',
      '남남서',
      '남서',
      '서남서',
      '서',
      '서북서',
      '북서',
      '북북서',
    ];
    return directions[((degrees + 11.25) / 22.5).floor() % 16];
  }

  String _kmaCondition(dynamic sky, dynamic pty) {
    final precipitation = int.tryParse(pty?.toString() ?? '') ?? 0;
    if (precipitation == 3 || precipitation == 7) return 'snow';
    if (precipitation == 2 || precipitation == 6) return 'sleet';
    if ([1, 4, 5].contains(precipitation)) return 'rain';
    return switch (int.tryParse(sky?.toString() ?? '')) {
      1 => 'clear',
      3 => 'cloudy',
      4 => 'overcast',
      _ => 'cloudy',
    };
  }
}
