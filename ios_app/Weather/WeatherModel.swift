import Foundation
import CoreLocation
import SwiftUI

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
    let precipitation: Double?
    let condition: Sky
}
struct HourWeather: Codable, Identifiable {
    let time: String
    let temperature: Double?
    let condition: Sky
    let precipitationProbability: Double?
    var id: String { time }
    var label: String { WeatherSnapshot.kstLabel(time, format: "H시") }
}
struct DayWeather: Codable, Identifiable {
    let date: String
    let low: Double?
    let high: Double?
    let condition: Sky
    let precipitationProbability: Double?
    var id: String { date }
    var label: String { String(date.suffix(5)).replacingOccurrences(of: "-", with: "/") }
}
struct WeatherSnapshot: Codable {
    let source: String
    let isDemo: Bool
    let observedAt: String
    let current: CurrentWeather
    let hourly: [HourWeather]
    let daily: [DayWeather]
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
        let current = CurrentWeather(temperature: 21, humidity: 68, windSpeed: 2.4, precipitation: sky.wet ? 1.5 : 0, condition: sky)
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

@MainActor final class WeatherStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var place: Place
    @Published var weather: WeatherSnapshot?
    @Published var error: String?
    @Published var loading = false
    @Published var locating = false
    @Published var endpoint: String
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
        guard !endpoint.isEmpty else { weather = nil; loading = false; return }
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
            weather = try JSONDecoder().decode(WeatherSnapshot.self, from: data)
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
