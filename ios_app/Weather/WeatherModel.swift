import Foundation
import CoreLocation
import SwiftUI
import Security
import WidgetKit

struct Place: Identifiable, Equatable {
    let name: String
    let region: String
    let lat: Double
    let lon: Double
    var id: String { name }
    static let cities = [
        Place(name: "서울", region: "대한민국 · 서울특별시", lat: 37.5665, lon: 126.978),
        Place(name: "부산", region: "대한민국 · 부산광역시", lat: 35.1796, lon: 129.0756),
        Place(name: "인천", region: "대한민국 · 인천광역시", lat: 37.4563, lon: 126.7052),
        Place(name: "대구", region: "대한민국 · 대구광역시", lat: 35.8714, lon: 128.6014),
        Place(name: "대전", region: "대한민국 · 대전광역시", lat: 36.3504, lon: 127.3845),
        Place(name: "광주", region: "대한민국 · 광주광역시", lat: 35.1595, lon: 126.8526),
        Place(name: "제주", region: "대한민국 · 제주특별자치도", lat: 33.4996, lon: 126.5312),
        Place(name: "강릉", region: "대한민국 · 강원특별자치도", lat: 37.7519, lon: 128.8761),
        Place(name: "수원", region: "대한민국 · 경기도", lat: 37.2636, lon: 127.0286),
        Place(name: "울산", region: "대한민국 · 울산광역시", lat: 35.5384, lon: 129.3114),
        Place(name: "전주", region: "대한민국 · 전북특별자치도", lat: 35.8242, lon: 127.148),
        Place(name: "청주", region: "대한민국 · 충청북도", lat: 36.6424, lon: 127.489)
    ]
}

enum Sky: String, Codable, CaseIterable {
    case clear, cloudy, overcast, rain, snow, sleet
    var title: String {
        switch self { case .clear: return "맑음"; case .cloudy: return "구름 많음"; case .overcast: return "흐림"; case .rain: return "비"; case .snow: return "눈"; case .sleet: return "비와 눈" }
    }
    var symbol: String {
        switch self { case .clear: return "sun.max.fill"; case .cloudy: return "cloud.sun.fill"; case .overcast: return "cloud.fill"; case .rain: return "cloud.rain.fill"; case .snow: return "cloud.snow.fill"; case .sleet: return "cloud.sleet.fill" }
    }
    var wet: Bool { self == .rain || self == .snow || self == .sleet }
}
struct CurrentWeather: Codable {
    let temperature: Double?
    let humidity: Double?
    let windSpeed: Double?
    let windDirectionDegrees: Double?
    let windDirection: String?
    let windEastWest: Double?
    let windNorthSouth: Double?
    let precipitation: String?
    let precipitationType: String?
    let condition: Sky
    var dewPoint: Double? {
        guard let temperature, let humidity, humidity > 0, humidity <= 100 else { return nil }
        let gamma = log(humidity / 100) + 17.625 * temperature / (243.04 + temperature)
        return 243.04 * gamma / (17.625 - gamma)
    }
    init(temperature: Double?, humidity: Double?, windSpeed: Double?, windDirectionDegrees: Double? = nil, windDirection: String? = nil, windEastWest: Double? = nil, windNorthSouth: Double? = nil, precipitation: String?, precipitationType: String? = nil, condition: Sky) {
        self.temperature = temperature; self.humidity = humidity; self.windSpeed = windSpeed
        self.windDirectionDegrees = windDirectionDegrees; self.windDirection = windDirection
        self.windEastWest = windEastWest; self.windNorthSouth = windNorthSouth
        self.precipitation = precipitation; self.precipitationType = precipitationType; self.condition = condition
    }
    private enum CodingKeys: String, CodingKey { case temperature, humidity, windSpeed, windDirectionDegrees, windDirection, windEastWest, windNorthSouth, precipitation, precipitationType, condition }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        temperature = try values.decodeIfPresent(Double.self, forKey: .temperature)
        humidity = try values.decodeIfPresent(Double.self, forKey: .humidity)
        windSpeed = try values.decodeIfPresent(Double.self, forKey: .windSpeed)
        windDirectionDegrees = try values.decodeIfPresent(Double.self, forKey: .windDirectionDegrees)
        windDirection = try values.decodeIfPresent(String.self, forKey: .windDirection)
        windEastWest = try values.decodeIfPresent(Double.self, forKey: .windEastWest)
        windNorthSouth = try values.decodeIfPresent(Double.self, forKey: .windNorthSouth)
        precipitationType = try values.decodeIfPresent(String.self, forKey: .precipitationType)
        condition = try values.decode(Sky.self, forKey: .condition)
        if let text = try? values.decode(String.self, forKey: .precipitation) { precipitation = text }
        else if let number = try? values.decode(Double.self, forKey: .precipitation) { precipitation = number == 0 ? "없음" : "\(number)mm" }
        else { precipitation = nil }
    }
}
struct HourWeather: Codable, Identifiable {
    let time: String
    let temperature: Double?
    let condition: Sky
    let precipitationProbability: Double?
    let humidity: Double?
    let windSpeed: Double?
    let windDirectionDegrees: Double?
    let windDirection: String?
    let precipitationAmount: String?
    let snowAmount: String?
    let waveHeight: Double?
    let lightning: Bool?
    init(time: String, temperature: Double?, condition: Sky, precipitationProbability: Double?, humidity: Double? = nil, windSpeed: Double? = nil, windDirectionDegrees: Double? = nil, windDirection: String? = nil, precipitationAmount: String? = nil, snowAmount: String? = nil, waveHeight: Double? = nil, lightning: Bool? = nil) {
        self.time = time; self.temperature = temperature; self.condition = condition; self.precipitationProbability = precipitationProbability
        self.humidity = humidity; self.windSpeed = windSpeed; self.windDirectionDegrees = windDirectionDegrees; self.windDirection = windDirection
        self.precipitationAmount = precipitationAmount; self.snowAmount = snowAmount; self.waveHeight = waveHeight; self.lightning = lightning
    }
    var id: String { time }
    var label: String { WeatherSnapshot.kstLabel(time, format: "H시") }
}
struct DayWeather: Codable, Identifiable {
    let date: String
    let low: Double?
    let high: Double?
    let condition: Sky
    let precipitationProbability: Double?
    init(date: String, low: Double?, high: Double?, condition: Sky, precipitationProbability: Double?) {
        self.date = date; self.low = low; self.high = high; self.condition = condition; self.precipitationProbability = precipitationProbability
    }
    var id: String { date }
    var label: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d EEE"
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: date).map(formatter.string(from:)) ?? date
    }
}
struct WeatherSnapshot: Codable {
    let source: String
    let isDemo: Bool
    let observedAt: String
    let forecastIssuedAt: String?
    let ultraForecastIssuedAt: String?
    let fetchedAt: String?
    let current: CurrentWeather
    let hourly: [HourWeather]
    let daily: [DayWeather]
    init(source: String, isDemo: Bool, observedAt: String, current: CurrentWeather, hourly: [HourWeather], daily: [DayWeather], forecastIssuedAt: String? = nil, ultraForecastIssuedAt: String? = nil, fetchedAt: String? = nil) {
        self.source = source; self.isDemo = isDemo; self.observedAt = observedAt; self.current = current
        self.hourly = hourly; self.daily = daily; self.forecastIssuedAt = forecastIssuedAt; self.ultraForecastIssuedAt = ultraForecastIssuedAt; self.fetchedAt = fetchedAt
    }
    static func kstLabel(_ string: String, format: String) -> String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let precise = parser.date(from: string)
        parser.formatOptions = [.withInternetDateTime]
        guard let date = precise ?? parser.date(from: string) else { return "—" }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 3600)
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    static func demo(_ sky: Sky) -> WeatherSnapshot {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        let temperatures: [Double] = [21,22,23,23,22,21,20,19,18,18,17,18]
        var hours: [HourWeather] = []
        for (i, temperature) in temperatures.enumerated() {
            let stamp = formatter.string(from: now.addingTimeInterval(Double(i) * 3600))
            hours.append(HourWeather(time: stamp, temperature: temperature, condition: sky, precipitationProbability: sky.wet ? 80 : 10))
        }
        var days: [DayWeather] = []
        for i in 0..<4 {
            let stamp = formatter.string(from: now.addingTimeInterval(Double(i) * 86400))
            days.append(DayWeather(date: kstLabel(stamp, format: "yyyy-MM-dd"), low: Double(16+i), high: Double(23+i), condition: sky, precipitationProbability: sky.wet ? 80 : 10))
        }
        let current = CurrentWeather(temperature: 21, humidity: 68, windSpeed: 2.4, precipitation: sky.wet ? "1.5mm" : "없음", condition: sky)
        return WeatherSnapshot(source: "디자인 미리보기", isDemo: true, observedAt: formatter.string(from: now), current: current, hourly: hours, daily: days)
    }
}
func value(_ number: Double?, _ unit: String = "", decimals: Int = 0) -> String {
    guard let number else { return "—" }
    return String(format: "%.*f", decimals, number) + unit
}
func validEndpoint(_ string: String) -> Bool {
    guard let parts = URLComponents(string: string), let host = parts.host, !host.isEmpty,
          parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
          parts.path.isEmpty || parts.path == "/" else { return false }
    return parts.scheme == "https" || (parts.scheme == "http" && ["localhost", "127.0.0.1"].contains(host))
}

enum WeatherCredentialVault {
    private static let service = "com.limhiru.weather.kma-key"
    private static let account = "service-key"
    static func read() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account,
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func write(_ key: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(key.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
    static func delete() {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
    }
}

enum DirectKMA {
    static func grid(_ lat: Double, _ lon: Double) throws -> (Int, Int) {
        guard (33...39.5).contains(lat), (124...132).contains(lon) else {
            throw NSError(domain: "Weather", code: 1, userInfo: [NSLocalizedDescriptionKey: "기상청 예보는 대한민국 지역에서 이용할 수 있어요."])
        }
        let pi = Double.pi, re = 6371.00877 / 5.0, slat1 = 30.0 * pi / 180, slat2 = 60.0 * pi / 180
        let olon = 126.0 * pi / 180, olat = 38.0 * pi / 180, x0 = 43.0, y0 = 136.0
        let sn = log(cos(slat1) / cos(slat2)) / log(tan(pi / 4 + slat2 / 2) / tan(pi / 4 + slat1 / 2))
        let sf = pow(tan(pi / 4 + slat1 / 2), sn) * cos(slat1) / sn
        let ro = re * sf / pow(tan(pi / 4 + olat / 2), sn)
        let ra = re * sf / pow(tan(pi / 4 + lat * pi / 360), sn)
        var theta = lon * pi / 180 - olon
        if theta > pi { theta -= 2 * pi }; if theta < -pi { theta += 2 * pi }; theta *= sn
        return (Int(floor(ra * sin(theta) + x0 + 0.5)), Int(floor(ro - ra * cos(theta) + y0 + 0.5)))
    }
    static func issueTimes(now: Date) -> (Date, Date, Date) {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let c = calendar.dateComponents([.year,.month,.day,.hour,.minute], from: now)
        let start = calendar.date(from: DateComponents(year: c.year, month: c.month, day: c.day, hour: c.hour, minute: c.minute))!
        let observation = calendar.date(bySetting: .minute, value: 0, of: start.addingTimeInterval(-40 * 60))!
        let eligible = start.addingTimeInterval(-10 * 60)
        let day = calendar.startOfDay(for: eligible)
        let forecastHours = [2,5,8,11,14,17,20,23]
        let forecast = forecastHours.compactMap { calendar.date(bySetting: .hour, value: $0, of: day) }.filter { $0 <= eligible }.last
            ?? calendar.date(bySetting: .hour, value: 23, of: calendar.date(byAdding: .day, value: -1, to: day)!)!
        let ultraAvailable = start.addingTimeInterval(-45 * 60)
        let ultraParts = calendar.dateComponents([.year,.month,.day,.hour,.minute], from: ultraAvailable)
        let ultraMinute = (ultraParts.minute ?? 0) >= 30 ? 30 : 0
        let ultra = calendar.date(from: DateComponents(year: ultraParts.year, month: ultraParts.month, day: ultraParts.day, hour: ultraParts.hour, minute: ultraMinute))!
        return (observation, forecast, ultra)
    }
    static func iso(_ date: Date) -> String { let f = ISO8601DateFormatter(); f.timeZone = TimeZone(secondsFromGMT: 9 * 3600); f.formatOptions = [.withInternetDateTime]; return f.string(from: date) }
    static func number(_ value: Any?) -> Double? {
        guard let value else { return nil }; let n = (value as? NSNumber)?.doubleValue ?? Double("\(value)")
        return n.flatMap { $0.isFinite && $0 > -90 ? $0 : nil }
    }
    static func sky(_ sky: Any?, _ pty: Any?) -> Sky {
        let precipitation = Int(number(pty) ?? 0), code = Int(number(sky) ?? 1)
        if precipitation == 1 || precipitation == 4 || precipitation == 5 { return .rain }
        if precipitation == 2 || precipitation == 6 { return .sleet }
        if precipitation == 3 || precipitation == 7 { return .snow }
        return code == 1 ? .clear : (code == 3 ? .cloudy : .overcast)
    }
    static func direction(_ raw: Any?) -> String? {
        guard let degrees = number(raw) else { return nil }
        let values = ["북","북북동","북동","동북동","동","동남동","남동","남남동","남","남남서","남서","서남서","서","서북서","북서","북북서"]
        return values[Int((degrees + 11.25) / 22.5) % 16]
    }
    static func amount(_ raw: Any?, unit: String) -> String? {
        guard let raw else { return nil }
        let text = "\(raw)"
        if text.isEmpty || text == "-" { return nil }
        if ["0","0.0","강수없음","적설없음"].contains(text) { return "없음" }
        if let value = number(raw) { return "\(value == floor(value) ? String(Int(value)) : String(value))\(unit)" }
        return text
    }
    static func request(_ operation: String, key: String, issue: Date, grid: (Int,Int)) async throws -> [[String: Any]] {
        let f = DateFormatter(); f.timeZone = TimeZone(secondsFromGMT: 9 * 3600); f.dateFormat = "yyyyMMdd"; let date = f.string(from: issue)
        f.dateFormat = "HHmm"; let time = f.string(from: issue)
        var parts = URLComponents(); parts.scheme = "https"; parts.host = "apis.data.go.kr"; parts.path = "/1360000/VilageFcstInfoService_2.0/\(operation)"
        parts.queryItems = [URLQueryItem(name:"serviceKey",value:key), URLQueryItem(name:"pageNo",value:"1"), URLQueryItem(name:"numOfRows",value:"2000"), URLQueryItem(name:"dataType",value:"JSON"), URLQueryItem(name:"base_date",value:date), URLQueryItem(name:"base_time",value:time), URLQueryItem(name:"nx",value:"\(grid.0)"), URLQueryItem(name:"ny",value:"\(grid.1)")]
        guard let url = parts.url else { throw NSError(domain:"Weather",code:2,userInfo:[NSLocalizedDescriptionKey:"기상청 요청 주소를 만들 수 없어요."]) }
        let (data,response) = try await URLSession.shared.data(for: URLRequest(url:url,timeoutInterval:25))
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let root = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let body = root["response"] as? [String:Any], let header = body["header"] as? [String:Any],
              ["00","0"].contains("\(header["resultCode"] ?? "")"),
              let content = body["body"] as? [String:Any], let items = content["items"] as? [String:Any] else {
            throw NSError(domain:"Weather",code:3,userInfo:[NSLocalizedDescriptionKey:"기상청 요청에 실패했어요. 인증키와 활용 신청 상태를 확인해 주세요."])
        }
        if let rows = items["item"] as? [[String:Any]] { return rows }
        if let row = items["item"] as? [String:Any] { return [row] }
        throw NSError(domain:"Weather",code:4,userInfo:[NSLocalizedDescriptionKey:"기상청 예보 자료가 아직 준비되지 않았어요."])
    }
    static func fetch(key: String, place: Place) async throws -> WeatherSnapshot {
        let now = Date(), times = issueTimes(now: now), grid = try grid(place.lat, place.lon)
        async let observedRows = request("getUltraSrtNcst", key:key, issue:times.0, grid:grid)
        async let forecastRows = request("getVilageFcst", key:key, issue:times.1, grid:grid)
        async let rapidRows = request("getUltraSrtFcst", key:key, issue:times.2, grid:grid)
        let observations = try await observedRows, forecast = try await forecastRows
        let rapid = (try? await rapidRows) ?? []
        let obs = Dictionary(uniqueKeysWithValues: observations.compactMap { row -> (String,Any)? in guard let k = row["category"] as? String, let v = row["obsrValue"] else { return nil }; return (k,v) })
        var slots: [Date:[String:Any]] = [:]
        let df = DateFormatter(); df.timeZone = TimeZone(secondsFromGMT: 9 * 3600); df.dateFormat = "yyyyMMddHHmm"
        for row in forecast {
            guard let d = row["fcstDate"] as? String, let t = row["fcstTime"] as? String, let category = row["category"] as? String, let value = row["fcstValue"], let stamp = df.date(from:d + t) else { continue }
            slots[stamp, default:[:]][category] = value
        }
        var rapidSlots: [Date:[String:Any]] = [:]
        for row in rapid {
            guard let d = row["fcstDate"] as? String, let t = row["fcstTime"] as? String, let category = row["category"] as? String, let value = row["fcstValue"], let stamp = df.date(from:d + t) else { continue }
            rapidSlots[stamp, default:[:]][category] = value
        }
        let hour = floor((now.timeIntervalSince1970 + 9 * 3600) / 3600) * 3600 - 9 * 3600
        let ordered = slots.keys.sorted().filter { $0.timeIntervalSince1970 >= hour && Self.number(slots[$0]?["TMP"]) != nil }
        guard let temperature = Self.number(obs["T1H"]), !ordered.isEmpty else { throw NSError(domain:"Weather",code:5,userInfo:[NSLocalizedDescriptionKey:"기상청 관측 자료가 아직 준비되지 않았어요. 잠시 뒤 다시 시도해 주세요."]) }
        let closest = slots.keys.min(by:{ abs($0.timeIntervalSince(now)) < abs($1.timeIntervalSince(now)) })!
        let allHours = ordered.compactMap { date -> HourWeather? in
            guard let row = slots[date], let temp = Self.number(row["TMP"]) else { return nil }
            let quick = rapidSlots[date] ?? [:]
            let sky = quick["SKY"] ?? row["SKY"], pty = quick["PTY"] ?? row["PTY"]
            let vector = quick["VEC"] ?? row["VEC"]
            return HourWeather(time:Self.iso(date),temperature:Self.number(quick["T1H"]) ?? temp,condition:Self.sky(sky,pty),precipitationProbability:Self.number(row["POP"]),humidity:Self.number(quick["REH"]) ?? Self.number(row["REH"]),windSpeed:Self.number(quick["WSD"]) ?? Self.number(row["WSD"]),windDirectionDegrees:Self.number(vector),windDirection:Self.direction(vector),precipitationAmount:Self.amount(quick["RN1"] ?? row["PCP"],unit:"mm"),snowAmount:Self.amount(row["SNO"],unit:"cm"),waveHeight:Self.number(row["WAV"]),lightning:(Self.number(quick["LGT"]) ?? 0) > 0)
        }
        let hours = Array(allHours.prefix(24))
        let grouped = Dictionary(grouping: allHours) { String($0.time.prefix(10)) }
        let severity: [Sky:Int] = [.clear:0,.cloudy:1,.overcast:2,.rain:3,.sleet:4,.snow:5]
        let days = grouped.keys.sorted().compactMap { date -> DayWeather? in
            guard let rows = grouped[date], !rows.isEmpty else { return nil }
            let temps = rows.compactMap(\.temperature), pops = rows.compactMap(\.precipitationProbability)
            let daySlots = slots.filter { Self.iso($0.key).hasPrefix(date) }.map(\.value)
            let low = daySlots.compactMap { Self.number($0["TMN"]) }.first ?? temps.min()
            let high = daySlots.compactMap { Self.number($0["TMX"]) }.first ?? temps.max()
            return DayWeather(date:date,low:low,high:high,condition:rows.map(\.condition).max(by:{severity[$0,default:0] < severity[$1,default:0]}) ?? .clear,precipitationProbability:pops.max())
        }
        let pty = Int(Self.number(obs["PTY"]) ?? 0)
        let precipType = [1,5].contains(pty) ? "비" : ([2,6].contains(pty) ? "비와 눈" : ([3,7].contains(pty) ? "눈" : (pty == 4 ? "소나기" : "없음")))
        let current = CurrentWeather(temperature:temperature,humidity:Self.number(obs["REH"]),windSpeed:Self.number(obs["WSD"]),windDirectionDegrees:Self.number(obs["VEC"]),windDirection:Self.direction(obs["VEC"]),windEastWest:Self.number(obs["UUU"]),windNorthSouth:Self.number(obs["VVV"]),precipitation:Self.amount(obs["RN1"],unit:"mm"),precipitationType:precipType,condition:Self.sky(slots[closest]?["SKY"],obs["PTY"] ?? slots[closest]?["PTY"]))
        return WeatherSnapshot(source:"기상청",isDemo:false,observedAt:Self.iso(times.0),current:current,hourly:hours,daily:days,forecastIssuedAt:Self.iso(times.1),ultraForecastIssuedAt:rapid.isEmpty ? nil : Self.iso(times.2),fetchedAt:Self.iso(now))
    }
}

enum WeatherWidgetCache {
    static let group = "group.com.limhiru.weather"
    static func save(_ weather: WeatherSnapshot, place: Place) {
        guard let defaults = UserDefaults(suiteName: group) else { return }
        defaults.set(place.name, forKey: "widget.city")
        if let temperature = weather.current.temperature {
            defaults.set(String(format: "%.0f°", temperature), forKey: "widget.temperature")
        } else { defaults.removeObject(forKey: "widget.temperature") }
        defaults.set(weather.current.condition.rawValue, forKey: "widget.condition")
        defaults.set(weather.observedAt, forKey: "widget.updated")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

@MainActor final class WeatherStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var place: Place
    @Published var weather: WeatherSnapshot?
    @Published var error: String?
    @Published var loading = false
    @Published var locating = false
    @Published var endpoint: String
    @Published var apiKey: String
    @Published var demo: Sky?
    private let locationManager = CLLocationManager()
    private var generation = 0
    private var locationTimeout: Task<Void, Never>?
    override init() {
        place = Place.cities.first(where: { $0.name == UserDefaults.standard.string(forKey: "city") }) ?? Place.cities[0]
        #if DEBUG
        endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? "http://localhost:8080"
        #else
        endpoint = UserDefaults.standard.string(forKey: "endpoint") ?? ""
        #endif
        apiKey = WeatherCredentialVault.read() ?? ""
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--preview") { demo = .clear }
        #endif
    }
    func select(_ place: Place) async {
        self.place = place
        UserDefaults.standard.set(place.name, forKey: "city")
        weather = nil
        await refresh()
    }
    func connect(_ endpoint: String) async {
        self.endpoint = endpoint
        UserDefaults.standard.set(endpoint, forKey: "endpoint")
        demo = nil
        weather = nil
        await refresh()
    }
    func configure(endpoint: String, apiKey: String) async {
        self.endpoint = endpoint
        self.apiKey = apiKey
        UserDefaults.standard.set(endpoint, forKey: "endpoint")
        do {
            if apiKey.isEmpty { WeatherCredentialVault.delete() } else { try WeatherCredentialVault.write(apiKey) }
        } catch { self.error = "인증키를 기기의 보안 저장소에 저장하지 못했어요."; return }
        demo = nil; weather = nil
        await refresh()
    }
    func preview(_ sky: Sky?) async {
        demo = sky
        weather = nil
        await refresh()
    }
    func refresh() async {
        generation += 1
        let requestID = generation
        error = nil
        if let demo { weather = .demo(demo); loading = false; return }
        guard !apiKey.isEmpty || !endpoint.isEmpty else { weather = nil; loading = false; return }
        if !apiKey.isEmpty {
            loading = true
            defer { if requestID == generation { loading = false } }
            do { let snapshot = try await DirectKMA.fetch(key: apiKey, place: place); if requestID == generation { weather = snapshot; WeatherWidgetCache.save(snapshot, place: place) } }
            catch { if requestID == generation { self.error = error.localizedDescription } }
            return
        }
        guard validEndpoint(endpoint), var parts = URLComponents(string: endpoint) else { error = "설정에서 HTTPS 날씨 서버 주소를 입력해 주세요."; return }
        parts.path = "/v1/weather"
        parts.queryItems = [URLQueryItem(name: "lat", value: String(place.lat)), URLQueryItem(name: "lon", value: String(place.lon))]
        guard let url = parts.url else { return }
        loading = true
        defer { if requestID == generation { loading = false } }
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 45))
            guard requestID == generation else { return }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                let body = try? JSONDecoder().decode([String: String].self, from: data)
                error = body?["error"] ?? "날씨를 불러오지 못했어요. 잠시 뒤 다시 시도해 주세요."
                return
            }
            let snapshot = try JSONDecoder().decode(WeatherSnapshot.self, from: data)
            weather = snapshot
            WeatherWidgetCache.save(snapshot, place: place)
        } catch {
            if requestID == generation { self.error = "서버에 연결할 수 없어요. 주소와 네트워크를 확인해 주세요." }
        }
    }
    func locate() {
        locating = true
        locationTimeout?.cancel()
        locationTimeout = Task {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard !Task.isCancelled, locating else { return }
            locating = false
            error = "위치를 확인하지 못했어요. 도시를 직접 선택해 주세요."
        }
        switch locationManager.authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: locationManager.requestLocation()
        default: locating = false; error = "설정에서 위치 권한을 허용하거나 도시를 직접 선택해 주세요."
        }
    }
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if locating { locate() }
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            guard locating else { return }
            locating = false
            locationTimeout?.cancel()
            guard (33...39.5).contains(coordinate.latitude), (124...132).contains(coordinate.longitude) else { error = "기상청 예보는 대한민국 지역에서 이용할 수 있어요."; return }
            await select(Place(name: "현재 위치", region: "대한민국 · 내 주변", lat: coordinate.latitude, lon: coordinate.longitude))
        }
    }
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in locating = false; self.error = "위치를 확인하지 못했어요. 도시를 직접 선택해 주세요." }
    }
}
