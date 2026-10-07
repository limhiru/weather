import SwiftUI
import WidgetKit

private struct WidgetHour: Identifiable {
  let time: String
  let temperature: String
  let condition: String
  let probability: String?
  var id: String { time }
  var forecastDate: Date? { Self.parse(time) }

  init?(row: [String: Any]) {
    guard let time = row["time"] as? String else { return nil }
    self.time = time
    self.temperature = (row["temperature"] as? NSNumber).map { "\($0.intValue)°" } ?? "—°"
    self.condition = row["condition"] as? String ?? "clear"
    if let value = row["precipitationProbability"] as? NSNumber {
      self.probability = "강수 \(value.intValue)%"
    } else {
      self.probability = nil
    }
  }

  var label: String {
    guard let date = Self.parse(time) else { return "—시" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "H시"
    return formatter.string(from: date)
  }

  var symbol: String { Self.weather(condition).1 }

  private static func parse(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }

  private static func weather(_ raw: String) -> (String, String) {
    switch raw {
    case "rain": return ("비", "cloud.rain.fill")
    case "snow": return ("눈", "cloud.snow.fill")
    case "sleet": return ("비와 눈", "cloud.sleet.fill")
    case "cloudy": return ("구름 많음", "cloud.sun.fill")
    case "overcast": return ("흐림", "cloud.fill")
    default: return ("맑음", "sun.max.fill")
    }
  }
}

private struct WeatherEntry: TimelineEntry {
  let date: Date
  let city: String
  let temperature: String
  let condition: String
  let symbol: String
  let updated: String
  let hasWeather: Bool
  let hours: [WidgetHour]
  let sunrise: String
  let sunset: String
}

private struct WeatherProvider: TimelineProvider {
  func placeholder(in context: Context) -> WeatherEntry {
    WeatherEntry(
      date: .now, city: "서울", temperature: "22°", condition: "맑음", symbol: "sun.max.fill",
      updated: "기상청 제공", hasWeather: true,
      hours: [
        WidgetHour(row: [
          "time": "2026-10-07T12:00:00+09:00", "temperature": 22, "condition": "clear",
        ])!,
        WidgetHour(row: [
          "time": "2026-10-07T13:00:00+09:00", "temperature": 23, "condition": "cloudy",
        ])!,
        WidgetHour(row: [
          "time": "2026-10-07T14:00:00+09:00", "temperature": 23, "condition": "rain",
          "precipitationProbability": 40,
        ])!,
        WidgetHour(row: [
          "time": "2026-10-07T15:00:00+09:00", "temperature": 22, "condition": "overcast",
        ])!,
      ], sunrise: "06:28", sunset: "18:05"
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
    completion(read())
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
    completion(Timeline(entries: [read()], policy: .after(.now.addingTimeInterval(30 * 60))))
  }

  private func read() -> WeatherEntry {
    let defaults = UserDefaults(suiteName: "group.com.limhiru.weather")
    let temperature = defaults?.string(forKey: "widget.temperature")
    let condition = defaults?.string(forKey: "widget.condition") ?? "clear"
    let city = defaults?.string(forKey: "widget.city") ?? "서울"
    let stamp = defaults?.string(forKey: "widget.updated")
    let latitude = defaults?.object(forKey: "widget.latitude") as? Double ?? 37.5665
    let longitude = defaults?.object(forKey: "widget.longitude") as? Double ?? 126.978
    let rows =
      defaults?.data(forKey: "widget.hourly")
      .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []
    let current = Self.weather(condition)
    let parsedHours = rows.compactMap(WidgetHour.init(row:))
    var kstCalendar = Calendar(identifier: .gregorian)
    kstCalendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    let currentHour = kstCalendar.dateInterval(of: .hour, for: .now)?.start ?? .now
    let futureHours = parsedHours.filter { $0.forecastDate.map { $0 >= currentHour } ?? true }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    formatter.dateFormat = "H시"
    let observed = stamp.flatMap(Self.parseDate)
    let updated = observed.map { "기상청 제공 · \(formatter.string(from: $0)) 관측" } ?? "기상청 제공"
    let sun = Self.solarTimes(latitude: latitude, longitude: longitude, date: .now)
    return WeatherEntry(
      date: .now, city: city, temperature: temperature ?? "—°",
      condition: temperature == nil ? "앱을 열어 날씨를 불러오세요" : current.0,
      symbol: temperature == nil ? "drop.fill" : current.1,
      updated: updated, hasWeather: temperature != nil, hours: Array(futureHours.prefix(8)),
      sunrise: sun.0, sunset: sun.1
    )
  }

  private static func parseDate(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: value) { return date }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
  }

  private static func weather(_ raw: String) -> (String, String) {
    switch raw {
    case "rain": return ("비", "cloud.rain.fill")
    case "snow": return ("눈", "cloud.snow.fill")
    case "sleet": return ("비와 눈", "cloud.sleet.fill")
    case "cloudy": return ("구름 많음", "cloud.sun.fill")
    case "overcast": return ("흐림", "cloud.fill")
    default: return ("맑음", "sun.max.fill")
    }
  }

  private static func solarTimes(latitude: Double, longitude: Double, date: Date) -> (
    String, String
  ) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
    let day = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
    let days = calendar.range(of: .day, in: .year, for: date)?.count == 366 ? 366.0 : 365.0
    let gamma = 2 * Double.pi / days * (day - 1)
    let equation =
      229.18
      * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma) - 0.014615 * cos(2 * gamma)
        - 0.040849 * sin(2 * gamma))
    let declination =
      0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma) - 0.006758 * cos(2 * gamma)
      + 0.000907 * sin(2 * gamma) - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
    let latitudeRadians = latitude * .pi / 180
    let zenith = 90.833 * .pi / 180
    let cosine =
      (cos(zenith) - sin(latitudeRadians) * sin(declination))
      / (cos(latitudeRadians) * cos(declination))
    guard (-1...1).contains(cosine) else { return ("--:--", "--:--") }
    let angle = acos(cosine) * 180 / .pi
    let noon = 720 - 4 * longitude - equation
    func localTime(_ utcMinutes: Double) -> String {
      let minutes = ((Int((utcMinutes + 540).rounded()) % 1440) + 1440) % 1440
      return String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
    return (localTime(noon - 4 * angle), localTime(noon + 4 * angle))
  }
}

private struct WeatherWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: WeatherEntry

  @ViewBuilder var body: some View {
    switch family {
    case .accessoryCircular:
      Gauge(value: entry.hasWeather ? 0.7 : 0) { Image(systemName: entry.symbol) }
        .gaugeStyle(.accessoryCircular)
        .overlay {
          Text(entry.temperature).font(.system(size: 10, weight: .semibold)).offset(y: 15)
        }
    case .accessoryRectangular:
      HStack(spacing: 7) {
        Image(systemName: entry.symbol).contentTransition(.symbolEffect(.replace))
        VStack(alignment: .leading) {
          Text("\(entry.city)  \(entry.temperature)").font(.headline)
          Text(entry.condition).font(.caption)
        }
      }
    case .systemSmall:
      standardWidget(hours: 2, columns: 2, compact: true)
    case .systemLarge:
      standardWidget(hours: 8, columns: 4, compact: false)
    default:
      standardWidget(hours: 4, columns: 4, compact: false)
    }
  }

  private func standardWidget(hours: Int, columns: Int, compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: compact ? 5 : 8) {
      HStack(spacing: 6) {
        Image(systemName: "drop.fill").foregroundStyle(.cyan)
        Text(entry.city).font(.subheadline).lineLimit(1)
        Spacer(minLength: 2)
        Image(systemName: entry.symbol)
          .font(.title2)
          .foregroundStyle(iconColor(entry.condition))
          .contentTransition(.symbolEffect(.replace))
          .symbolEffect(.bounce, value: entry.condition)
          .animation(.easeInOut(duration: 0.8), value: entry.condition)
      }
      HStack(alignment: .firstTextBaseline, spacing: 7) {
        Text(entry.temperature)
          .font(.system(size: compact ? 35 : 43, weight: .light, design: .rounded))
          .contentTransition(.numericText())
          .animation(.easeInOut(duration: 0.8), value: entry.temperature)
        Text(entry.condition).font(compact ? .caption : .subheadline).lineLimit(1)
      }
      if columns == 4, hours > 4 {
        Text("시간별 예보").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.75))
        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 6
        ) {
          ForEach(Array(entry.hours.prefix(hours))) { hour in hourlyCell(hour, compact: false) }
        }
      } else {
        HStack {
          Text("시간별").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.75))
          Spacer()
        }
        HStack(spacing: 5) {
          ForEach(Array(entry.hours.prefix(hours))) { hour in hourlyCell(hour, compact: compact) }
          if entry.hours.isEmpty {
            Text("앱을 열어 예보를 불러오세요").font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
          }
        }
      }
      Spacer(minLength: 0)
      HStack(spacing: compact ? 8 : 14) {
        Label(entry.sunrise, systemImage: "sunrise.fill").foregroundStyle(
          Color(red: 1, green: 0.84, blue: 0.58))
        Label(entry.sunset, systemImage: "sunset.fill").foregroundStyle(
          Color(red: 1, green: 0.75, blue: 0.65))
        Spacer(minLength: 0)
      }
      .font(.system(size: compact ? 8 : 9, weight: .medium))
      Text(entry.updated).font(.system(size: 8)).foregroundStyle(.white.opacity(0.62)).lineLimit(1)
    }
    .padding(compact ? 10 : 14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .foregroundStyle(.white)
    .containerBackground(for: .widget) {
      LinearGradient(colors: backgroundColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        .overlay(alignment: .topTrailing) {
          Circle().fill(.cyan.opacity(0.14)).frame(width: 100, height: 100).blur(radius: 30).offset(
            x: 24, y: -24)
        }
    }
  }

  private func hourlyCell(_ hour: WidgetHour, compact: Bool) -> some View {
    VStack(spacing: compact ? 1 : 3) {
      Text(hour.label).font(.system(size: compact ? 8 : 9)).foregroundStyle(.white.opacity(0.7))
      Image(systemName: hour.symbol).font(.system(size: compact ? 11 : 13)).foregroundStyle(
        iconColor(hour.condition))
      Text(hour.temperature).font(.system(size: compact ? 10 : 11, weight: .medium))
      if let probability = hour.probability {
        Text(probability).font(.system(size: 7)).foregroundStyle(.cyan.opacity(0.9)).lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity)
  }

  private var backgroundColors: [Color] {
    switch entry.condition {
    case "비", "눈", "비와 눈":
      return [Color(red: 0.12, green: 0.31, blue: 0.43), Color(red: 0.04, green: 0.13, blue: 0.22)]
    case "흐림":
      return [Color(red: 0.25, green: 0.36, blue: 0.43), Color(red: 0.08, green: 0.17, blue: 0.25)]
    default:
      return [Color(red: 0.08, green: 0.27, blue: 0.38), Color(red: 0.04, green: 0.13, blue: 0.22)]
    }
  }

  private func iconColor(_ condition: String) -> Color {
    switch condition {
    case "비", "눈", "비와 눈", "구름 많음", "흐림": return Color(red: 0.69, green: 0.9, blue: 1)
    default: return Color(red: 1, green: 0.85, blue: 0.51)
    }
  }
}

struct WeatherHomeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "WeatherHomeWidget", provider: WeatherProvider()) { entry in
      WeatherWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("물결 날씨")
    .description("시간별 예보와 일출·일몰, 오늘의 날씨를 확인해요.")
    .supportedFamilies([
      .systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular,
    ])
  }
}

@main struct WeatherWidgetBundle: WidgetBundle {
  var body: some Widget { WeatherHomeWidget() }
}
