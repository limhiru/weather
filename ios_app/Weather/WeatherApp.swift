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
                    Text("Power by 기상청").font(.system(size:11)).foregroundStyle(.white.opacity(0.65)).padding(.top,12)
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
                Text("서버를 연결하면 지금의 기온과\n시간별 예보를 함께 볼 수 있어요.").font(.subheadline).lineSpacing(5).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.65))
                Button("연결 설정하기") { settings = true }.buttonStyle(.borderedProminent).tint(.cyan.opacity(0.65))
                Button("먼저 둘러보기") { Task { await store.preview(.clear) } }.tint(.white)
            }.frame(maxWidth:.infinity) }
        }
    }
    @ViewBuilder private func weatherContent(_ weather: WeatherSnapshot) -> some View {
        VStack(spacing:7) {
            Text(value(weather.current.temperature,"°")).font(.system(size:112,weight:.ultraLight,design:.rounded)).tracking(-7).contentTransition(.numericText())
            Label(weather.current.condition.title,systemImage:weather.current.condition.symbol).font(.system(size:20,weight:.light)).symbolRenderingMode(.hierarchical)
            Text("잠시 멈춰, 오늘의 하늘을 느껴보세요.").font(.system(size:12)).foregroundStyle(.white.opacity(0.65)).padding(.top,3)
        }.padding(.bottom,12)
        LiquidCard {
            VStack(alignment:.leading,spacing:20) {
                section("시간별 예보",symbol:"clock",trailing:"24시간 이내")
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:26) { ForEach(weather.hourly) { hour in
                        VStack(spacing:12) { Text(hour.label).font(.system(size:12)).foregroundStyle(.white.opacity(0.65)); Image(systemName:hour.condition.symbol).symbolRenderingMode(.hierarchical).font(.system(size:23)).foregroundStyle(Color(red:0.77,green:0.93,blue:1)).frame(height:25); VStack(spacing:3) { Text(value(hour.temperature,"°")).font(.system(size:19)); Text(value(hour.precipitationProbability,"%")).font(.system(size:10)).foregroundStyle(.cyan.opacity(0.8)) } }
                    } }
                }
            }
        }
        LiquidCard {
            VStack(spacing:19) {
                section("다가오는 날씨",symbol:"calendar",trailing:"예보 구간")
                ForEach(weather.daily) { day in
                    HStack(spacing:12) {
                        Text(day.label).font(.system(size:15)).frame(width:45,alignment:.leading)
                        Image(systemName:day.condition.symbol).symbolRenderingMode(.hierarchical).foregroundStyle(.cyan.opacity(0.8)).frame(width:25)
                        Text(value(day.precipitationProbability,"%")).font(.system(size:10)).foregroundStyle(.cyan.opacity(0.8)).frame(width:30)
                        Spacer(minLength:0)
                        Text(value(day.low,"°")).foregroundStyle(.white.opacity(0.6))
                        Capsule().fill(LinearGradient(colors:[.cyan,Color(red:1,green:0.85,blue:0.59)],startPoint:.leading,endPoint:.trailing)).frame(width:52,height:4)
                        Text(value(day.high,"°"))
                    }.font(.system(size:15))
                }
                Divider().overlay(.white.opacity(0.1))
                Text("표시된 예보 시간대의 최저·최고 기온입니다.").font(.system(size:10)).foregroundStyle(.white.opacity(0.6))
            }
        }
        HStack(spacing:14) {
            metric("습도",symbol:"humidity",number:value(weather.current.humidity,"%"),caption:"공기 속 수분")
            metric("바람",symbol:"wind",number:value(weather.current.windSpeed," m/s",decimals:1),caption:"현재 풍속")
        }
        LiquidCard { HStack { Image(systemName:"umbrella").foregroundStyle(.cyan.opacity(0.8)); Text("최근 1시간 강수량").font(.subheadline); Spacer(); Text(value(weather.current.precipitation," mm",decimals:1)).font(.system(size:21,weight:.light)) } }
        VStack(spacing:7) { Text(weather.isDemo ? "예시 데이터 · 실제 날씨가 아닙니다" : "기상청 제공 · \(WeatherSnapshot.kstLabel(weather.observedAt,format:"M/d HH:mm")) 관측 (KST)"); Text("아래로 당겨 새로고침").foregroundStyle(.white.opacity(0.35)) }.font(.system(size:10)).foregroundStyle(.white.opacity(0.6)).padding(.top,8)
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
    @State private var invalid = false
    var body: some View {
        NavigationStack {
            Form {
                Section { TextField("https://weather.example.com",text:$endpoint).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    if invalid { Text("HTTPS 주소 또는 로컬 개발 서버 주소를 입력해 주세요.").font(.caption).foregroundStyle(.orange) }
                    Button("저장하고 기상청 날씨 보기") { let address = endpoint.trimmingCharacters(in:.whitespacesAndNewlines); guard validEndpoint(address) else { invalid = true; return }; dismiss(); Task { await store.connect(address) } }
                } header: { Text("날씨 서버 주소") } footer: { Text("기상청 인증키는 서버에서만 보관해요. 배포한 서버의 HTTPS 주소를 입력해 주세요.") }
                Section { ForEach(Sky.allCases,id:\.rawValue) { sky in Button { dismiss(); Task { await store.preview(sky) } } label: { Label(sky.title,systemImage:sky.symbol) } }
                    if store.demo != nil { Button("미리보기 종료") { dismiss(); Task { await store.preview(nil) } } }
                } header: { Text("디자인 미리보기") } footer: { Text("미리보기의 날씨는 실제 관측값이 아닌 예시예요.") }
                Section { LabeledContent("버전",value:Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"); Text("Power by 기상청 · 대한민국 단기예보").font(.footnote); Link("기상청 API 인증키 발급 안내",destination:URL(string:"https://www.data.go.kr/data/15084084/openapi.do")!) }
            }.navigationTitle("설정").toolbar { ToolbarItem(placement:.topBarTrailing) { Button("완료") { dismiss() } } }.onAppear { endpoint = store.endpoint }
        }
    }
}
