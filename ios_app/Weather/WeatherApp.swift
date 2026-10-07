import SwiftUI

@main struct WeatherApp: App {
    var body: some Scene {
        WindowGroup { WeatherView().preferredColorScheme(.dark) }
    }
}
struct WeatherView: View {
    @StateObject private var store = WeatherStore()
    @State private var cities = false
    @State private var settings = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            LivingSky(sky: store.weather?.current.condition ?? .clear)
            ScrollView {
                VStack(spacing: 16) {
                    toolbar
                    VStack(spacing: 8) {
                        Text(store.place.region).font(.system(size:11)).tracking(2).foregroundStyle(.white.opacity(0.65))
                        Button { cities = true } label: { HStack(spacing:8) { Text(store.place.name).font(.system(size:32,weight:.medium)); Image(systemName:"chevron.down").font(.caption) } }.tint(.white)
                        if store.demo != nil { Text("디자인 미리보기 · 실제 날씨 아님").font(.system(size:11)).padding(.horizontal,14).padding(.vertical,7).modifier(GlassControl()) }
                    }.padding(.top,8)
                    if store.loading || store.locating { ProgressView(store.locating ? "현재 위치를 찾고 있어요" : "기상청 날씨를 불러오고 있어요").tint(.white).font(.caption).padding() }
                    if let error = store.error {
                        LiquidCard { VStack(alignment:.leading,spacing:10) { Text(error).font(.subheadline); if store.weather != nil { Text("이전 조회 자료를 표시하고 있어요.").font(.caption).foregroundStyle(.yellow) }; Button("다시 시도") { Task { await store.refresh() } } } }
                    }
                    if let weather = store.weather { weatherContent(weather) }
                    else if !store.loading { welcome }
                    Text("기상청 제공").font(.system(size:11)).foregroundStyle(.white.opacity(0.65)).padding(.top,12)
                }.padding(.horizontal,22).padding(.bottom,30)
            }.refreshable { await store.refresh() }
        }
        .foregroundStyle(.white)
        .sheet(isPresented:$cities) { CitySheet(store:store).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented:$settings) { SettingsSheet(store:store).presentationDetents([.large]).presentationDragIndicator(.visible) }
        .task { await store.refresh() }
        .onChange(of:scenePhase) { _,phase in if phase == .active && !store.loading { Task { await store.refresh() } } }
    }
    private var toolbar: some View {
        HStack { Image(systemName:"drop").font(.title3); Text("물결").font(.system(size:20,weight:.semibold)).tracking(3); Spacer()
            HStack(spacing:4) {
                Button { cities = true } label: { Image(systemName:"building.2").frame(width:44,height:44) }.accessibilityLabel("도시 선택")
                Button { settings = true } label: { Image(systemName:"slider.horizontal.3").frame(width:44,height:44) }.accessibilityLabel("설정")
            }.modifier(GlassControl())
        }.padding(.top,8).tint(.white)
    }
    private var welcome: some View {
        VStack(spacing:24) {
            Image(systemName:"drop").font(.system(size:65,weight:.ultraLight)).foregroundStyle(.cyan.opacity(0.8)).padding(.top,48)
            Text("오늘의 하늘을,\n한 방울에.").font(.system(size:34,weight:.light)).multilineTextAlignment(.center)
            LiquidCard { VStack(spacing:14) {
                Text("기상청 날씨 연결").font(.title3.weight(.semibold))
                Text("기상청 인증키를 입력하면 지금의 기온과\n자세한 예보를 볼 수 있어요.").font(.subheadline).lineSpacing(5).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.65))
                Button("연결 설정하기") { settings = true }.buttonStyle(.borderedProminent).tint(.cyan.opacity(0.65))
                Button("먼저 둘러보기") { Task { await store.preview(.clear) } }.tint(.white)
            }.frame(maxWidth:.infinity) }
        }
    }
    @ViewBuilder private func weatherContent(_ weather: WeatherSnapshot) -> some View {
        let nextHours = Array(weather.hourly.prefix(6))
        let rainPeak = nextHours.compactMap(\.precipitationProbability).max()
        let rainSoon = nextHours.contains { $0.condition.wet || ($0.precipitationAmount != nil && $0.precipitationAmount != "없음") }
        let umbrellaNeeded = (rainPeak ?? 0) >= 50 || rainSoon
        VStack(spacing:7) {
            Text(value(weather.current.temperature,"°")).font(.system(size:112,weight:.ultraLight,design:.rounded)).tracking(-7).contentTransition(.numericText())
            Label(weather.current.condition.title,systemImage:weather.current.condition.symbol).font(.system(size:20,weight:.light)).symbolRenderingMode(.hierarchical)
            Text("잠시 멈춰, 오늘의 하늘을 느껴보세요.").font(.system(size:12)).foregroundStyle(.white.opacity(0.65)).padding(.top,3)
        }.padding(.bottom,12)
        LiquidCard {
            HStack(spacing:12) {
                Image(systemName: umbrellaNeeded ? "umbrella.fill" : "sun.max.fill").foregroundStyle(.cyan)
                VStack(alignment:.leading,spacing:4) {
                    Text(rainPeak.map { "앞으로 6시간 강수확률 최고 \(Int($0.rounded()))%" } ?? "가까운 시간대 강수 예보").font(.subheadline.weight(.semibold))
                    Text(umbrellaNeeded ? "가까운 시간에 비나 눈이 예상돼요. 우산을 챙기세요." : "가까운 시간대 강수 가능성이 낮아요.").font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength:0)
            }
        }
        LiquidCard {
            VStack(alignment:.leading,spacing:20) {
                section("시간별 예보",symbol:"clock",trailing:"24시간 · 날짜별 3일")
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:26) { ForEach(weather.hourly) { hour in
                        VStack(spacing:7) {
                            Text(hour.label).font(.system(size:12)).foregroundStyle(.white.opacity(0.65))
                            Image(systemName:hour.condition.symbol).symbolRenderingMode(.hierarchical).font(.system(size:23)).foregroundStyle(Color(red:0.77,green:0.93,blue:1)).frame(height:25)
                            Text(value(hour.temperature,"°")).font(.system(size:19))
                            Text("비 \(value(hour.precipitationProbability,"%"))").font(.system(size:10)).foregroundStyle(.cyan.opacity(0.8))
                            Text("습도 \(value(hour.humidity,"%"))").font(.system(size:9)).foregroundStyle(.white.opacity(0.6))
                            Text("\(hour.windDirection ?? "바람") \(value(hour.windSpeed,"m/s"))").font(.system(size:9)).foregroundStyle(.white.opacity(0.6))
                            if let amount = hour.precipitationAmount, amount != "없음" { Text("강수 \(amount)").font(.system(size:9)).foregroundStyle(.cyan) }
                            if let snow = hour.snowAmount, snow != "없음" { Text("눈 \(snow)").font(.system(size:9)).foregroundStyle(.white.opacity(0.8)) }
                            if let wave = hour.waveHeight { Text(String(format:"파고 %.1fm",wave)).font(.system(size:9)).foregroundStyle(.white.opacity(0.7)) }
                            if hour.lightning == true { Text("낙뢰 가능성").font(.system(size:9)).foregroundStyle(.yellow) }
                        }
                    } }
                }
            }
        }
        LiquidCard {
            VStack(spacing:19) {
                section("날짜별 예보",symbol:"calendar",trailing:"기상청 최저·최고")
                ForEach(weather.daily) { day in
                    HStack(spacing:12) {
                        Text(day.label).font(.system(size:13)).frame(width:76,alignment:.leading)
                        Image(systemName:day.condition.symbol).symbolRenderingMode(.hierarchical).foregroundStyle(.cyan.opacity(0.8)).frame(width:25)
                        Text(value(day.precipitationProbability,"%")).font(.system(size:10)).foregroundStyle(.cyan.opacity(0.8)).frame(width:30)
                        Spacer(minLength:0)
                        Text(value(day.low,"°")).foregroundStyle(.white.opacity(0.6))
                        Capsule().fill(LinearGradient(colors:[.cyan,Color(red:1,green:0.85,blue:0.59)],startPoint:.leading,endPoint:.trailing)).frame(width:52,height:4)
                        Text(value(day.high,"°"))
                    }.font(.system(size:15))
                }
                Divider().overlay(.white.opacity(0.1))
                Text(weather.isDemo ? "기온과 예보는 미리보기용 예시입니다." : "날짜별 기상청 최저·최고 기온 (제공되지 않으면 시간별 예보 범위)").font(.system(size:10)).foregroundStyle(.white.opacity(0.6))
            }
        }
        HStack(spacing:14) {
            metric("습도",symbol:"humidity",number:value(weather.current.humidity,"%"),caption:"공기 속 수분")
            metric("바람",symbol:"wind",number:value(weather.current.windSpeed," m/s",decimals:1),caption:"현재 \(weather.current.windDirection ?? "") \(weather.current.windDirectionDegrees.map { "\(Int($0.rounded()))°" } ?? "")")
        }
        LiquidCard { HStack { Image(systemName:"humidity.fill").foregroundStyle(.cyan.opacity(0.8)); Text("이슬점 · 기온과 습도로 계산").font(.subheadline); Spacer(); Text(value(weather.current.dewPoint,"°")).font(.system(size:21,weight:.light)) } }
        LiquidCard { HStack { Image(systemName:"umbrella").foregroundStyle(.cyan.opacity(0.8)); VStack(alignment:.leading,spacing:4) { Text("최근 1시간 강수량").font(.subheadline); Text("현재 강수형태 · \(weather.current.precipitationType ?? "—")").font(.caption).foregroundStyle(.white.opacity(0.6)) }; Spacer(); Text(weather.current.precipitation ?? "—").font(.system(size:21,weight:.light)) } }
        if weather.current.windEastWest != nil || weather.current.windNorthSouth != nil {
            Text("바람 성분  동서 \(value(weather.current.windEastWest,"m/s",decimals:1))  ·  남북 \(value(weather.current.windNorthSouth,"m/s",decimals:1))").font(.system(size:10)).foregroundStyle(.white.opacity(0.55))
        }
        VStack(spacing:7) { Text(weather.isDemo ? "예시 데이터 · 실제 날씨가 아닙니다" : "기상청 제공 · \(WeatherSnapshot.kstLabel(weather.observedAt,format:"M/d HH:mm")) 관측 (KST)\(weather.forecastIssuedAt.map { " · 예보 \(WeatherSnapshot.kstLabel($0,format:"M/d HH:mm")) 발표" } ?? "")\(weather.ultraForecastIssuedAt.map { " · 초단기 \(WeatherSnapshot.kstLabel($0,format:"HH:mm")) 발표" } ?? "")"); Text("아래로 당겨 새로고침").foregroundStyle(.white.opacity(0.35)) }.font(.system(size:10)).foregroundStyle(.white.opacity(0.6)).padding(.top,8)
    }
    private func section(_ title:String,symbol:String,trailing:String) -> some View {
        HStack { Label(title,systemImage:symbol).font(.system(size:12)).foregroundStyle(.white.opacity(0.65)); Spacer(); Text(trailing).font(.system(size:10)).foregroundStyle(.white.opacity(0.4)) }
    }
    private func metric(_ title:String,symbol:String,number:String,caption:String) -> some View {
        LiquidCard { VStack(alignment:.leading,spacing:14) { Label(title,systemImage:symbol).font(.system(size:12)).foregroundStyle(.white.opacity(0.65)); Text(number).font(.system(size:29,weight:.light)).minimumScaleFactor(0.6).lineLimit(1); Text(caption).font(.system(size:11)).foregroundStyle(.white.opacity(0.5)) } }
    }
}
struct CitySheet: View {
    @ObservedObject var store: WeatherStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var body: some View {
        NavigationStack {
            List {
                Button { dismiss(); store.locate() } label: { Label("현재 위치 사용",systemImage:"location.fill") }
                ForEach(Place.cities.filter { query.isEmpty || $0.name.contains(query) || $0.region.contains(query) }) { place in
                    Button { dismiss(); Task { await store.select(place) } } label: {
                        HStack { VStack(alignment:.leading,spacing:5) { Text(place.name).font(.headline); Text(place.region).font(.caption).foregroundStyle(.secondary) }; Spacer(); if store.place == place { Image(systemName:"checkmark.circle") } }.foregroundStyle(.white)
                    }
                }
            }.searchable(text:$query,prompt:"도시 검색").navigationTitle("도시 선택").toolbar { ToolbarItem(placement:.topBarTrailing) { Button("완료") { dismiss() } } }
        }
    }
}
struct SettingsSheet: View {
    @ObservedObject var store: WeatherStore
    @Environment(\.dismiss) private var dismiss
    @State private var endpoint = ""
    @State private var apiKey = ""
    @State private var invalid = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("일반 인증키 (Decoding)", text:$apiKey).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("HTTPS 서버 주소 (선택)",text:$endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if invalid { Text("기상청 인증키 또는 올바른 HTTPS 서버 주소를 입력해 주세요.").font(.caption).foregroundStyle(.orange) }
                    Button("저장하고 기상청 날씨 보기") {
                        let address = endpoint.trimmingCharacters(in:.whitespacesAndNewlines), key = apiKey.trimmingCharacters(in:.whitespacesAndNewlines)
                        guard (!address.isEmpty && validEndpoint(address)) || !key.isEmpty else { invalid = true; return }
                        guard key.isEmpty || (key.count >= 20 && !key.contains(where: \.isWhitespace)) else { invalid = true; return }
                        dismiss(); Task { await store.configure(endpoint:address,apiKey:key) }
                    }
                } header: { Text("휴대폰에서 직접 연결") } footer: { Text("인증키를 입력하면 서버 없이 기상청에 직접 연결해요. 키는 이 기기의 Keychain에 저장됩니다. 기상청 활용 신청 승인 후 일반 인증키(Decoding)를 사용하세요.") }
                Section { ForEach(Sky.allCases,id:\.rawValue) { sky in Button { dismiss(); Task { await store.preview(sky) } } label: { Label(sky.title,systemImage:sky.symbol) } }
                    if store.demo != nil { Button("미리보기 종료") { dismiss(); Task { await store.preview(nil) } } }
                } header: { Text("디자인 미리보기") } footer: { Text("미리보기의 날씨는 실제 관측값이 아닌 예시예요.") }
                Section { LabeledContent("버전",value:Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"); Text("기상청 제공 · 대한민국 단기예보").font(.footnote); Link("기상청 API 인증키 발급 안내",destination:URL(string:"https://www.data.go.kr/data/15084084/openapi.do")!) }
            }.navigationTitle("설정").toolbar { ToolbarItem(placement:.topBarTrailing) { Button("완료") { dismiss() } } }.onAppear { endpoint = store.endpoint; apiKey = store.apiKey }
        }
    }
}
