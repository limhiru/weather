import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'weather.dart';
import 'sky.dart';
import 'version.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '물결 날씨',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xff123650),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffb1e8fc),
        brightness: Brightness.dark,
      ),
      fontFamily: 'sans-serif',
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xff193b54),
        showDragHandle: true,
      ),
    ),
    home: const WeatherHome(),
  );
}

IconData weatherIcon(String condition) => switch (condition) {
  'rain' => Icons.water_drop_rounded,
  'snow' => Icons.ac_unit_rounded,
  'sleet' => Icons.grain_rounded,
  'cloudy' || 'overcast' => Icons.cloud_rounded,
  _ => Icons.wb_sunny_rounded,
};

class WeatherHome extends StatefulWidget {
  const WeatherHome({super.key});
  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> with WidgetsBindingObserver {
  Place place = places.first;
  WeatherData? data;
  String endpoint = const String.fromEnvironment(
    'WEATHER_API_URL',
    defaultValue: kDebugMode ? 'http://10.0.2.2:8080' : '',
  );
  String apiKey = '';
  String? error;
  bool loading = false, demo = false;
  String demoCondition = 'clear';
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    restore();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loading) {
      refresh();
    }
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final savedKey = await WeatherApi.credentials.read(key: 'kma_service_key');
    if (!mounted) {
      return;
    }
    setState(() {
      endpoint = prefs.getString('endpoint') ?? endpoint;
      apiKey = savedKey ?? '';
      place = places.firstWhere(
        (p) => p.name == prefs.getString('city'),
        orElse: () => places.first,
      );
    });
    await refresh();
  }

  Future<void> refresh() async {
    final request = ++generation;
    if (demo) {
      setState(() {
        data = WeatherData.demo(demoCondition);
        error = null;
        loading = false;
      });
      return;
    }
    if (endpoint.isEmpty && apiKey.isEmpty) {
      setState(() {
        data = null;
        error = null;
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await WeatherApi().fetch(endpoint, place, apiKey: apiKey);
      if (mounted && request == generation) {
        setState(() => data = result);
      }
    } catch (e) {
      if (mounted && request == generation) {
        setState(
          () => error = e is TimeoutException
              ? '응답이 늦어지고 있어요. 다시 시도해 주세요.'
              : e.toString().startsWith('Exception:')
              ? e.toString().replaceFirst('Exception: ', '')
              : '서버에 연결할 수 없어요. 설정에서 주소와 네트워크를 확인해 주세요.',
        );
      }
    } finally {
      if (mounted && request == generation) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> selectPlace(Place value) async {
    setState(() {
      place = value;
      data = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', value.name);
    if (mounted) {
      await refresh();
    }
  }

  Future<void> locate() async {
    Navigator.pop(context);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 필요해요. 도시를 직접 선택할 수도 있어요.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) {
        return;
      }
      if (position.latitude < 33 ||
          position.latitude > 39.5 ||
          position.longitude < 124 ||
          position.longitude > 132) {
        throw Exception('기상청 예보는 대한민국 지역에서 이용할 수 있어요.');
      }
      await selectPlace(
        Place('현재 위치', '대한민국 · 내 주변', position.latitude, position.longitude),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().startsWith('Exception:')
                  ? e.toString().replaceFirst('Exception: ', '')
                  : '위치를 확인하지 못했어요. 도시를 선택해 주세요.',
            ),
          ),
        );
      }
    }
  }

  void citySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setModal) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .68,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '어디의 하늘이 궁금하세요?',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (v) => setModal(() => query = v),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: '도시 검색',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.near_me_outlined),
                      title: const Text('현재 위치 사용'),
                      onTap: locate,
                    ),
                    Expanded(
                      child: ListView(
                        children: places
                            .where(
                              (p) =>
                                  p.name.contains(query) ||
                                  p.region.contains(query),
                            )
                            .map(
                              (p) => ListTile(
                                title: Text(p.name),
                                subtitle: Text(p.region),
                                trailing: place.name == p.name
                                    ? const Icon(Icons.check_circle_outline)
                                    : null,
                                onTap: () {
                                  Navigator.pop(context);
                                  selectPlace(p);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void settings() {
    final controller = TextEditingController(text: endpoint);
    final keyController = TextEditingController(text: apiKey);
    String? validation;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModal) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '하늘을 연결하는 방법',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                const Text(
                  '기상청 인증키를 입력하면 서버 없이 휴대폰에서 직접 불러와요.\n인증키는 기기의 보안 저장소에 보관됩니다. HTTPS 서버도 사용할 수 있어요.',
                  style: TextStyle(color: Colors.white70, height: 1.6),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: '날씨 서버 주소',
                    hintText: 'https://weather.example.com',
                    errorText: validation,
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: '기상청 일반 인증키 (Decoding)',
                    hintText: '이 휴대폰에 안전하게 저장',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final value = controller.text.trim();
                    final secret = keyController.text.trim();
                    if (value.isNotEmpty && !validEndpoint(value)) {
                      setModal(
                        () => validation = 'HTTPS 주소 또는 로컬 개발 서버 주소를 입력해 주세요.',
                      );
                      return;
                    }
                    if (secret.isEmpty && value.isEmpty) {
                      setModal(() => validation = '기상청 인증키 또는 날씨 서버 주소를 입력해 주세요.');
                      return;
                    }
                    if (secret.isNotEmpty && (secret.length < 20 || secret.contains(RegExp(r'\s')))) {
                      setModal(() => validation = '기상청 일반 인증키를 확인해 주세요.');
                      return;
                    }
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('endpoint', value);
                    if (secret.isEmpty) {
                      await WeatherApi.credentials.delete(key: 'kma_service_key');
                    } else {
                      await WeatherApi.credentials.write(key: 'kma_service_key', value: secret);
                    }
                    if (!mounted || !sheetContext.mounted) {
                      return;
                    }
                    setState(() {
                      endpoint = value;
                      apiKey = secret;
                      demo = false;
                      data = null;
                    });
                    Navigator.pop(sheetContext);
                    refresh();
                  },
                  child: const Text('저장하고 기상청 날씨 보기'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(),
                ),
                const Text(
                  '디자인 미리보기',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const Text(
                  '아래의 날씨는 실제 관측값이 아닌 예시예요.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['clear', 'cloudy', 'rain', 'snow', 'sleet']
                      .map(
                        (c) => ActionChip(
                          avatar: Icon(weatherIcon(c), size: 17),
                          label: Text(conditionLabel(c)),
                          onPressed: () {
                            setState(() {
                              demo = true;
                              demoCondition = c;
                              data = null;
                            });
                            Navigator.pop(sheetContext);
                            refresh();
                          },
                        ),
                      )
                      .toList(),
                ),
                if (demo)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        demo = false;
                        data = null;
                      });
                      Navigator.pop(sheetContext);
                      refresh();
                    },
                    child: const Text('미리보기 종료'),
                  ),
                const SizedBox(height: 22),
                const Text(
                  '물결 날씨 · $appVersion\nPower by 기상청 · 대한민국 단기예보',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final weather = data;
    final hour = DateTime.now().toUtc().add(const Duration(hours: 9)).hour;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: LivingSky(
              condition: weather?.condition ?? 'clear',
              night: hour < 6 || hour >= 19,
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop_outlined, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        '물결',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '도시 선택',
                        onPressed: citySheet,
                        icon: const Icon(Icons.location_city_rounded),
                      ),
                      IconButton(
                        tooltip: '설정',
                        onPressed: settings,
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      place.region,
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: citySheet,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            place.name,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const Icon(Icons.expand_more, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                  if (demo)
                    Center(
                      child: Chip(
                        label: const Text(
                          '디자인 미리보기 · 실제 날씨 아님',
                          style: TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.white.withValues(alpha: .12),
                        side: BorderSide.none,
                      ),
                    ),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: LiquidPanel(
                        child: Column(
                          children: [
                            Text(error!, style: const TextStyle(height: 1.5)),
                            if (weather != null)
                              const Text(
                                '이전 조회 자료를 표시하고 있어요.',
                                style: TextStyle(color: Colors.amberAccent),
                              ),
                            TextButton(
                              onPressed: refresh,
                              child: const Text('다시 시도'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (weather == null && !loading) ...[
                    const SizedBox(height: 60),
                    const Icon(
                      Icons.water_drop_outlined,
                      size: 70,
                      color: Color(0xffb3e6ff),
                    ),
                    const SizedBox(height: 30),
                    const Center(
                      child: Text(
                        '오늘의 하늘을,\n한 방울에.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w300,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),
                    LiquidPanel(
                      child: Column(
                        children: [
                          const Text(
                            '기상청 날씨 연결',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '서버를 연결하면 지금의 기온과\n시간별 예보를 함께 볼 수 있어요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: settings,
                            child: const Text('연결 설정하기'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => demo = true);
                              refresh();
                            },
                            child: const Text('먼저 둘러보기'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (weather != null) ...[
                    Center(
                      child: Text(
                        numberText(weather.current['temperature'], '°'),
                        style: const TextStyle(
                          fontSize: 112,
                          fontWeight: FontWeight.w200,
                          height: 1.15,
                          letterSpacing: -7,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          weatherIcon(weather.condition),
                          size: 19,
                          color: const Color(0xffd2efff),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          conditionLabel(weather.condition),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    const Center(
                      child: Text(
                        '잠시 멈춰, 오늘의 하늘을 느껴보세요.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 28),
                    LiquidPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionTitle(Icons.schedule, '시간별 예보', '24시간 이내'),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 116,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: weather.hourly.length,
                              separatorBuilder: (_, i) =>
                                  const SizedBox(width: 24),
                              itemBuilder: (context, i) {
                                final row = weather.hourly[i];
                                final date = koreanTime(row['time']);
                                return Column(
                                  children: [
                                    Text(
                                      '${date.hour}시',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(height: 13),
                                    Icon(
                                      weatherIcon(row['condition']),
                                      size: 23,
                                      color: const Color(0xffc5edff),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      numberText(row['temperature'], '°'),
                                      style: const TextStyle(fontSize: 19),
                                    ),
                                    Text(
                                      numberText(
                                        row['precipitationProbability'],
                                        '%',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xffa4dffa),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    LiquidPanel(
                      child: Column(
                        children: [
                          sectionTitle(
                            Icons.calendar_today_outlined,
                            '다가오는 날씨',
                            '예보 구간',
                          ),
                          const SizedBox(height: 12),
                          ...weather.daily.map((row) {
                            final date = DateTime.parse(row['date']);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 43,
                                    child: Text(
                                      '${date.month}/${date.day}',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                  Icon(
                                    weatherIcon(row['condition']),
                                    size: 21,
                                    color: const Color(0xffc5edff),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 31,
                                    child: Text(
                                      numberText(
                                        row['precipitationProbability'],
                                        '%',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xffa4dffa),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    numberText(row['low'], '°'),
                                    style: const TextStyle(
                                      color: Colors.white60,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 16,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xff75d5ed),
                                          Color(0xffffdf9d),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(numberText(row['high'], '°')),
                                ],
                              ),
                            );
                          }),
                          const Divider(color: Colors.white12),
                          const Text(
                            '표시된 예보 시간대의 최저·최고 기온입니다.',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: metric(
                            Icons.water_drop_outlined,
                            '습도',
                            numberText(weather.current['humidity'], '%'),
                            '공기 속 수분',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: metric(
                            Icons.air_rounded,
                            '바람',
                            weather.current['windSpeed'] == null
                                ? '—'
                                : '${weather.current['windSpeed']} m/s',
                            '현재 풍속',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    LiquidPanel(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.umbrella_outlined,
                            color: Color(0xffb6e3fb),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(child: Text('최근 1시간 강수량')),
                          Text(
                            weather.current['precipitation'] == null
                                ? '—'
                                : '${weather.current['precipitation']} mm',
                            style: const TextStyle(fontSize: 21),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        weather.isDemo
                            ? '예시 데이터 · 실제 날씨가 아닙니다'
                            : '기상청 제공 · ${weather.updated} 관측 (KST)',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Center(
                      child: Text(
                        '아래로 당겨 새로고침',
                        style: TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Power by 기상청',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(IconData icon, String title, String trailing) => Row(
    children: [
      Icon(icon, size: 14, color: Colors.white60),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      const Spacer(),
      Text(
        trailing,
        style: const TextStyle(fontSize: 10, color: Colors.white38),
      ),
    ],
  );
  Widget metric(IconData icon, String title, String value, String caption) =>
      LiquidPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: Colors.white60),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 17),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              caption,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ],
        ),
      );
}
