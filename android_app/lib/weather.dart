import 'dart:convert';
import 'package:http/http.dart' as http;

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
  Future<WeatherData> fetch(String endpoint, Place place) async {
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
}
