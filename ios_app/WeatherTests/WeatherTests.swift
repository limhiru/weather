import XCTest
@testable import Weather

final class WeatherTests: XCTestCase {
    func testEndpointValidation() {
        XCTAssertTrue(validEndpoint("https://weather.example.com"))
        XCTAssertTrue(validEndpoint("http://localhost:8080"))
        for address in ["http://example.com", "https://user:pass@example.com", "https://example.com?key=secret", "broken"] { XCTAssertFalse(validEndpoint(address)) }
    }
    func testKSTAcrossMidnight() {
        XCTAssertEqual(WeatherSnapshot.kstLabel("2026-01-01T15:00:00Z", format: "M/d H시"), "1/2 0시")
        XCTAssertEqual(WeatherSnapshot.kstLabel("2026-01-01T23:00:00+09:00", format: "H시"), "23시")
    }
    func testPreviewLabelsAndMissingValues() throws {
        let snapshot = WeatherSnapshot.demo(.snow)
        XCTAssertTrue(snapshot.isDemo)
        XCTAssertEqual(snapshot.current.condition, .snow)
        XCTAssertEqual(Weather.value(nil), "—")
        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WeatherSnapshot.self, from: encoded)
        XCTAssertEqual(decoded.hourly.count,12)
    }
}
