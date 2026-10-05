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
    private func drawSky(context: inout GraphicsContext, size: CGSize, time: Double) {
        let t = time
        let overcast = sky == .overcast, cloudy = sky == .cloudy
        let rainy = sky == .rain, snowy = sky == .snow, sleety = sky == .sleet
        let colors: [Color]
                if night {
                    let middle: Color
                    let bottom: Color
                    if overcast { middle = Color(red:0.15,green:0.19,blue:0.25); bottom = Color(red:0.22,green:0.27,blue:0.32) }
                    else if rainy { middle = Color(red:0.09,green:0.17,blue:0.25); bottom = Color(red:0.11,green:0.24,blue:0.32) }
                    else if snowy { middle = Color(red:0.23,green:0.3,blue:0.38); bottom = Color(red:0.34,green:0.42,blue:0.48) }
                    else if sleety { middle = Color(red:0.11,green:0.18,blue:0.26); bottom = Color(red:0.18,green:0.26,blue:0.32) }
                    else if cloudy { middle = Color(red:0.11,green:0.18,blue:0.3); bottom = Color(red:0.16,green:0.24,blue:0.36) }
                    else { middle = Color(red:0.14,green:0.22,blue:0.36); bottom = Color(red:0.14,green:0.31,blue:0.4) }
                    colors = [Color(red:0.04,green:0.08,blue:0.2),middle,bottom]
        } else if overcast {
            colors = [Color(red:0.27,green:0.32,blue:0.37),Color(red:0.47,green:0.51,blue:0.54),Color(red:0.32,green:0.38,blue:0.42)]
        } else if rainy {
            colors = [Color(red:0.15,green:0.23,blue:0.31),Color(red:0.33,green:0.47,blue:0.54),Color(red:0.12,green:0.25,blue:0.33)]
        } else if snowy {
            colors = [Color(red:0.33,green:0.41,blue:0.5),Color(red:0.57,green:0.67,blue:0.74),Color(red:0.37,green:0.49,blue:0.57)]
        } else if sleety {
            colors = [Color(red:0.2,green:0.28,blue:0.36),Color(red:0.43,green:0.54,blue:0.6),Color(red:0.21,green:0.34,blue:0.41)]
        } else if cloudy {
            colors = [Color(red:0.14,green:0.32,blue:0.46),Color(red:0.4,green:0.56,blue:0.64),Color(red:0.21,green:0.36,blue:0.47)]
        } else {
            colors = [Color(red:0.07,green:0.25,blue:0.45),Color(red:0.25,green:0.55,blue:0.7),Color(red:0.09,green:0.3,blue:0.44)]
        }
        context.fill(Path(CGRect(origin:.zero,size:size)),with:.linearGradient(Gradient(colors:colors),startPoint:.zero,endPoint:CGPoint(x:0,y:size.height)))
        let sun = CGPoint(x:size.width*0.78,y:size.height*0.16)
        let glow = overcast ? 0.025 : rainy || sleety ? 0.055 : cloudy ? 0.13 : 0.3
        let pulse = 0.94 + 0.06 * sin(t * 2 * .pi)
        let glowRadius = 178.0 * pulse
        context.fill(Path(ellipseIn:CGRect(x:sun.x-glowRadius,y:sun.y-glowRadius,width:glowRadius*2,height:glowRadius*2)),with:.radialGradient(Gradient(colors:[.cyan.opacity(night ? 0.09 : glow),.clear]),center:sun,startRadius:0,endRadius:glowRadius))
        if sky == .clear && !night {
            for i in 0..<12 {
                let angle = t * 2 * .pi + Double(i) * .pi / 6
                var ray = Path()
                ray.move(to: CGPoint(x:sun.x+cos(angle)*53,y:sun.y+sin(angle)*53))
                ray.addLine(to: CGPoint(x:sun.x+cos(angle)*88,y:sun.y+sin(angle)*88))
                context.stroke(ray,with:.color(Color(red:1,green:0.93,blue:0.76).opacity(0.15*pulse)),style:StrokeStyle(lineWidth:2,lineCap:.round))
            }
        }
        if !sky.wet && sky == .clear {
            let r: CGFloat = night ? 23 : 36
            context.fill(Path(ellipseIn:CGRect(x:sun.x-r,y:sun.y-r,width:r*2,height:r*2)),with:.color(night ? .white.opacity(0.85) : Color(red:1,green:0.9,blue:0.68)))
            if night { context.fill(Path(ellipseIn:CGRect(x:sun.x-12,y:sun.y-31,width:44,height:44)),with:.color(colors[0])) }
        }
        if night {
            for i in 0..<42 {
                let x = CGFloat((i*73)%401)/401*size.width
                let y = CGFloat((i*47)%397)/397*size.height*0.7
                let visibility = overcast ? 0.12 : cloudy ? 0.45 : sky.wet ? 0.25 : 1.0
                context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:2,height:2)),with:.color(.white.opacity((0.2+0.2*(1+sin(t*2*Double.pi+Double(i)))/2)*visibility)))
            }
        }
        context.drawLayer { layer in
            layer.addFilter(.blur(radius:26))
            let cloudCount = overcast ? 11 : cloudy ? 8 : 5
            for i in 0..<cloudCount {
                let drift = overcast ? 12.0 : cloudy ? 34.0 : 48.0
                let x = size.width*(Double(i)/Double(cloudCount-1)-0.15)+sin(t*2*Double.pi+Double(i)*0.8)*drift
                let y = size.height*(overcast ? 0.15+Double(i%4)*0.075 : 0.13+Double(i%3)*0.105)
                let width = overcast ? 285.0 : cloudy ? 245.0 : 210.0
                let height = overcast ? 86.0 : 62.0
                let opacity = overcast ? 0.24 : cloudy ? 0.17 : sky.wet ? 0.11 : 0.045
                layer.fill(Path(ellipseIn:CGRect(x:x-width/2,y:y-height/2,width:width,height:height)),with:.color(.white.opacity(opacity)))
            }
        }
        if sky.wet {
            let particleCount = snowy ? 58 : sleety ? 72 : 92
            for i in 0..<particleCount {
                let speed = snowy ? 1.25 : sleety ? 3.2 : 5.2
                let drift = snowy ? 22.0 : 8.0
                let x = (Double(i)*61.7+t*drift*20).truncatingRemainder(dividingBy:size.width)
                let y = (Double(i)*97.3+t*size.height*speed).truncatingRemainder(dividingBy:size.height)
                if snowy || (sleety && i%2 == 0) {
                    let r = Double(snowy ? 2+i%3 : 2+i%2)
                    context.fill(Path(ellipseIn:CGRect(x:x+sin(t*2*Double.pi+Double(i))*drift,y:y,width:r,height:r)),with:.color(.white.opacity(snowy ? 0.3 : 0.22)))
                } else {
                    var path = Path(); path.move(to:CGPoint(x:x,y:y)); path.addLine(to:CGPoint(x:x-(rainy ? 7 : 4),y:y+(rainy ? 24 : 18)+Double(i%12)))
                    context.stroke(path,with:.color(.white.opacity(0.2+Double(i%4)*0.07)),style:StrokeStyle(lineWidth:1.2,lineCap:.round))
                }
            }
            if rainy || sleety {
                for i in 0..<7 {
                    let x = size.width*(0.08+Double(i)*0.14)+sin(t*2*Double.pi+Double(i))*12
                    let phase = (t*1.8+Double(i)*0.17).truncatingRemainder(dividingBy:1)
                    let radius = 4+phase*20
                    let ripple = Path(ellipseIn:CGRect(x:x-radius*0.85,y:size.height*(0.83+phase*0.1),width:radius*1.7,height:3))
                    context.stroke(ripple,with:.color(.white.opacity((1-phase)*0.18)),lineWidth:1)
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
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || scenePhase != .active)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 20) / 20
            Canvas { context, size in
                drawSky(context: &context, size: size, time: t)
            }
        }.ignoresSafeArea().accessibilityHidden(true)
    }
}
