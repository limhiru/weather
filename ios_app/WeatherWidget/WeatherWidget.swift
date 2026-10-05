import WidgetKit
import SwiftUI

private struct WeatherEntry: TimelineEntry {
    let date: Date
    let city: String
    let temperature: String
    let condition: String
    let symbol: String
    let updated: String
    let hasWeather: Bool
}

private struct WeatherProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, city: "서울", temperature: "22°", condition: "맑음", symbol: "sun.max.fill", updated: "Power by 기상청", hasWeather: true)
    }
    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) { completion(read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        completion(Timeline(entries: [read()], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
    private func read() -> WeatherEntry {
        let defaults = UserDefaults(suiteName: "group.com.limhiru.weather")
        let temperature = defaults?.string(forKey: "widget.temperature")
        let condition = defaults?.string(forKey: "widget.condition") ?? "clear"
        let city = defaults?.string(forKey: "widget.city") ?? "서울"
        let stamp = defaults?.string(forKey: "widget.updated")
        let (label,symbol) = Self.label(condition)
        let date = stamp.flatMap(ISO8601DateFormatter().date(from:)) ?? .now
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "ko_KR"); formatter.dateFormat = "a h:mm"
        return WeatherEntry(date: .now, city: city, temperature: temperature ?? "--°", condition: temperature == nil ? "앱을 열어 날씨를 불러오세요" : label, symbol: temperature == nil ? "drop.fill" : symbol, updated: temperature == nil ? "Power by 기상청" : "기상청 · \(formatter.string(from: date))", hasWeather: temperature != nil)
    }
    private static func label(_ raw: String) -> (String,String) {
        switch raw {
        case "rain": return ("비","cloud.rain.fill")
        case "snow": return ("눈","cloud.snow.fill")
        case "sleet": return ("비와 눈","cloud.sleet.fill")
        case "cloudy": return ("구름 많음","cloud.sun.fill")
        case "overcast": return ("흐림","cloud.fill")
        default: return ("맑음","sun.max.fill")
        }
    }
}

private struct WeatherWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeatherEntry
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                Gauge(value: entry.hasWeather ? 0.7 : 0) { Image(systemName: entry.symbol) }
                    .gaugeStyle(.accessoryCircular).overlay { Text(entry.temperature).font(.system(size: 10,weight: .semibold)).offset(y: 15) }
            case .accessoryRectangular:
                HStack(spacing: 7) { Image(systemName:entry.symbol); VStack(alignment:.leading) { Text("\(entry.city)  \(entry.temperature)").font(.headline); Text(entry.condition).font(.caption) } }
            default:
                VStack(alignment:.leading,spacing:8) {
                    HStack { Image(systemName:"drop.fill").foregroundStyle(.cyan); Text(entry.city).font(.subheadline); Spacer(); Image(systemName:entry.symbol).font(.title2).foregroundStyle(.yellow.opacity(0.9)) }
                    HStack(alignment:.firstTextBaseline,spacing:8) { Text(entry.temperature).font(.system(size: family == .systemSmall ? 43 : 48,weight:.light,design:.rounded)); Text(entry.condition).font(.subheadline).lineLimit(1) }
                    Text("\(entry.updated)  ·  Power by 기상청").font(.system(size:9)).foregroundStyle(.white.opacity(0.65)).lineLimit(1)
                }.padding(14).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.leading)
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            LinearGradient(colors:[Color(red:0.08,green:0.27,blue:0.38),Color(red:0.04,green:0.13,blue:0.22)],startPoint:.topLeading,endPoint:.bottomTrailing)
                .overlay(alignment:.topTrailing) { Circle().fill(.cyan.opacity(0.14)).frame(width:100,height:100).blur(radius:30).offset(x:24,y:-24) }
        }
    }
}

struct WeatherHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind:"WeatherHomeWidget",provider:WeatherProvider()) { entry in WeatherWidgetEntryView(entry:entry) }
            .configurationDisplayName("물결 날씨")
            .description("현재 기온과 하늘을 한눈에 확인해요.")
            .supportedFamilies([.systemSmall,.systemMedium,.accessoryCircular,.accessoryRectangular])
    }
}

@main struct WeatherWidgetBundle: WidgetBundle {
    var body: some Widget { WeatherHomeWidget() }
}
