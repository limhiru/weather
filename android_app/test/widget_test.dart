import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather/main.dart';
import 'package:weather/weather.dart';

void main() {
  test('KST rendering remains correct on a foreign device timezone', () {
    final date = koreanTime('2026-01-01T23:00:00+09:00');
    expect(date.hour, 23);
    expect(koreanTime('2026-01-01T15:00:00Z').day, 2);
  });
  test(
    'endpoints reject credentials, insecure remote hosts and query strings',
    () {
      expect(validEndpoint('https://weather.example.com'), true);
      expect(validEndpoint('http://10.0.2.2:8080'), true);
      for (final value in [
        'http://example.com',
        'https://user:pass@example.com',
        'https://example.com?key=secret',
        'broken',
      ]) {
        expect(validEndpoint(value), false);
      }
    },
  );
  test('preview is explicitly labeled and missing values stay missing', () {
    expect(WeatherData.demo('rain').isDemo, true);
    expect(WeatherData.demo('snow').condition, 'snow');
    expect(numberText(null), '—');
  });
  testWidgets('first launch shows setup; preview and city choice work', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WeatherApp());
    await tester.pump();
    expect(find.text('기상청 날씨 연결'), findsOneWidget);
    expect(find.text('21°'), findsNothing);
    await tester.ensureVisible(find.text('먼저 둘러보기'));
    await tester.pump();
    await tester.tap(find.text('먼저 둘러보기'));
    await tester.pump();
    expect(find.text('디자인 미리보기 · 실제 날씨 아님'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.byTooltip('도시 선택'));
    await tester.pump();
    await tester.tap(find.byTooltip('도시 선택'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('부산'));
    await tester.pump();
    await tester.tap(find.text('부산'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('어디의 하늘이 궁금하세요?'), findsNothing);
    expect(find.text('대한민국 · 부산광역시'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('compact display has no layout overflow in preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const WeatherApp());
    await tester.pump();
    await tester.ensureVisible(find.text('먼저 둘러보기'));
    await tester.pump();
    await tester.ensureVisible(find.text('먼저 둘러보기'));
    await tester.pump();
    await tester.tap(find.text('먼저 둘러보기'));
    await tester.pump();
    await tester.drag(find.byType(ListView).first, const Offset(0, -550));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
