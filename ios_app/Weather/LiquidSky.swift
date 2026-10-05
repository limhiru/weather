import SwiftUI

struct LiquidCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(reduceTransparency ? Color(red: 0.12, green: 0.27, blue: 0.37) : Color.white.opacity(0.035))
            .background(.ultraThinMaterial.opacity(reduceTransparency ? 0 : 0.62))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.08), .white.opacity(0.17)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8))
    }
}
struct GlassControl: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else { fallback(content) }
        #else
        fallback(content)
        #endif
    }
    private func fallback(_ content: Content) -> some View {
        content.background(.ultraThinMaterial, in: Capsule()).overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.7))
    }
}

struct LivingSky: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let sky: Sky
    private var night: Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 32400)!
        let hour = calendar.component(.hour, from: Date())
        return hour < 6 || hour >= 19
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 20) / 20
            Canvas { context, size in
                let colors: [Color] = night ? [Color(red:0.04,green:0.08,blue:0.2),Color(red:0.14,green:0.22,blue:0.36),Color(red:0.14,green:0.31,blue:0.4)] : sky.wet ? [Color(red:0.12,green:0.21,blue:0.3),Color(red:0.29,green:0.48,blue:0.57),Color(red:0.08,green:0.25,blue:0.36)] : [Color(red:0.07,green:0.25,blue:0.45),Color(red:0.25,green:0.55,blue:0.7),Color(red:0.09,green:0.3,blue:0.44)]
                context.fill(Path(CGRect(origin:.zero,size:size)),with:.linearGradient(Gradient(colors:colors),startPoint:.zero,endPoint:CGPoint(x:0,y:size.height)))
                let sun = CGPoint(x:size.width*0.78,y:size.height*0.16)
                context.fill(Path(ellipseIn:CGRect(x:sun.x-150,y:sun.y-150,width:300,height:300)),with:.radialGradient(Gradient(colors:[.cyan.opacity(sky.wet ? 0.08 : 0.24),.clear]),center:sun,startRadius:0,endRadius:150))
                if !sky.wet && sky == .clear {
                    let r: CGFloat = night ? 23 : 36
                    context.fill(Path(ellipseIn:CGRect(x:sun.x-r,y:sun.y-r,width:r*2,height:r*2)),with:.color(night ? .white.opacity(0.85) : Color(red:1,green:0.9,blue:0.68)))
                    if night { context.fill(Path(ellipseIn:CGRect(x:sun.x-12,y:sun.y-31,width:44,height:44)),with:.color(colors[0])) }
                }
                if night {
                    for i in 0..<42 {
                        let x = CGFloat((i*73)%401)/401*size.width
                        let y = CGFloat((i*47)%397)/397*size.height*0.7
                        context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:2,height:2)),with:.color(.white.opacity(0.2+0.2*(1+sin(t*2*Double.pi+Double(i)))/2)))
                    }
                }
                context.drawLayer { layer in
                    layer.addFilter(.blur(radius:26))
                    for i in 0..<7 {
                        let x = size.width*(Double(i)/5-0.2)+sin(t*2*Double.pi+Double(i))*28
                        let y = size.height*(0.13+Double(i%3)*0.105)
                        layer.fill(Path(ellipseIn:CGRect(x:x-115,y:y-31,width:230,height:62)),with:.color(.white.opacity(sky == .clear ? 0.05 : 0.15)))
                    }
                }
                if sky.wet {
                    for i in 0..<65 {
                        let x = (Double(i)*61.7+t*55).truncatingRemainder(dividingBy:size.width)
                        let y = (Double(i)*97.3+t*size.height*(sky == .snow ? 2 : 5)).truncatingRemainder(dividingBy:size.height)
                        if sky == .snow || (sky == .sleet && i%2 == 0) {
                            let r = Double(2+i%3)
                            context.fill(Path(ellipseIn:CGRect(x:x+sin(t*2*Double.pi+Double(i))*12,y:y,width:r,height:r)),with:.color(.white.opacity(0.5)))
                        } else {
                            var path = Path(); path.move(to:CGPoint(x:x,y:y)); path.addLine(to:CGPoint(x:x-4,y:y+18+Double(i%12)))
                            context.stroke(path,with:.color(.white.opacity(0.2+Double(i%4)*0.07)),style:StrokeStyle(lineWidth:1.2,lineCap:.round))
                        }
                    }
                }
                for i in 0..<8 {
                    let r = Double(13+(i%3)*14)
                    let x = size.width*Double(i*37%97)/97
                    let y = size.height*(0.3+Double(i*19%67)/100)+sin(t*2*Double.pi+Double(i))*14
                    let rect = CGRect(x:x-r,y:y-r,width:r*2,height:r*2)
                    context.fill(Path(ellipseIn:rect),with:.radialGradient(Gradient(colors:[.white.opacity(0.16),.cyan.opacity(0.01),.white.opacity(0.12)]),center:CGPoint(x:x-r*0.4,y:y-r*0.5),startRadius:0,endRadius:r*1.5))
                    var rim = Path(); rim.addArc(center:CGPoint(x:x,y:y),radius:r,startAngle:.degrees(180),endAngle:.degrees(310),clockwise:false)
                    context.stroke(rim,with:.color(.white.opacity(0.25)),lineWidth:1)
                    context.fill(Path(ellipseIn:CGRect(x:x-r*0.35,y:y-r*0.43,width:r*0.2,height:r*0.12)),with:.color(.white.opacity(0.5)))
                }
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
